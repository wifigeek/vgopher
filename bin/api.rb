#!/usr/bin/env ruby
$:.push File.expand_path(File.dirname(__FILE__) + '/../lib')

require 'sinatra'
require 'ohm_objects'
require 'word_salad'
require 'util'

set :bind, '0.0.0.0'
set :port, 9494
set :public_folder, File.dirname(__FILE__) + '/static'
set :logging, true

#Ohm.redis = Redic.new("redis://127.0.0.1:6379/1")

Ohm.redis = Redic.new("redis://127.0.0.1:8888/1")

helpers do
include Logging

# process sets/arrays generated from qbuilder for output. 
def qoutput(base_ohm_object, attribs)
	# if no attributes were defined, set the base attribs to return for an object/group
	if attribs.empty?
		attribs = ['overallstatus', 'accessible', 'uuid']
	end
	
	if base_ohm_object.is_a?(Array) && base_ohm_object.count > 1
		base_ohm_object.flatten!
	end

	base_ohm_object.map do |obj|
		@output[obj.name.to_sym] = obj.attributes.select {|atr| atr if attribs.include?(atr.to_s) }
	end

end

# build search for specific object or range of objects(regex)
def qbuild_object(base_ohm_object,value)

	tmp_base_ohm_object = []

	# unless the object type is an array or an Ohm List, use find method to query redis
	unless base_ohm_object.is_a?(Array) || base_ohm_object.is_a?(Ohm::List)
		tmp_base_ohm_object = base_ohm_object.find(name: value)
	end
	
	# if the object type is an array and it contains more than 1 element, flatten the array
	if base_ohm_object.is_a?(Array) && base_ohm_object.count > 1
		base_ohm_object.flatten!
	end

	# if there wasn't anything found using find method(tmp_base_ohm_object.empty?), attempt to find the object using regex
	tmp_base_ohm_object = base_ohm_object.select {|obj| obj if Regexp.new(value) === obj.name } if tmp_base_ohm_object.empty?
	
	# toss up an error no objects were found
	halt 402, "unable to find #{value}" if tmp_base_ohm_object.empty?

	# set the new base_ohm_object
	@base_ohm_object = tmp_base_ohm_object
	logger.debug "qbuild_object #{value} #{base_ohm_object.count}"

end

# build saerch for a collection
def qbuild_collection(base_ohm_object,value)

	if base_ohm_object.is_a?(Array) && base_ohm_object.count > 1
		@base_ohm_object = base_ohm_object.collect {|obj| obj.public_send(value).select {|objx| objx } }#[0]
	else
		@base_ohm_object = base_ohm_object.first.public_send(value)
	end

end

def qbuilder(collections_objects)
	
	@output = Hash.new { |hash, key| hash[key] = [] }
	
	# an index match will yield Ohm::Set
	@base_ohm_object = @ohm_ob.find(name: @object)
	# a regexp match will yield an Array
	@base_ohm_object = @ohm_ob.all.find_all {|obj| obj if Regexp.new(@object) === obj.name} if @base_ohm_object.empty?
	# return error if unable to find anything
	halt 402, "unable to find #{@object}" if @base_ohm_object.empty?

	# unless there aren't any collections or objects to search, build the query
	unless collections_objects.select { |x| x =~ /col|obj/ }.empty?
		collections_objects.each do |key,value|
			if key.to_s =~ /col/
				qbuild_collection(@base_ohm_object,value)
			elsif key.to_s =~ /obj/
				qbuild_object(@base_ohm_object,value)
			end
		end

	end

	# send to output method
	qoutput(@base_ohm_object, collections_objects[:attribs])

end

def splat_sort(splat_vals)

	# get all valid attribute/collection terms for base object_bucket
	bucket_words = @@word_buckets[0][@object_bucket].values_at(:attributes, :collections, :lists).flatten.compact

	# unless the first term in the array is an attribute or collection, error out
	unless bucket_words.include?(splat_vals[0])
		halt 402, "first value must be an attribute or collection of #{@object_bucket} - #{@object} select from #{bucket_words}"
	end

	# create an empty hash which will contain sorted elements. 
	collections_objects = Hash.new { |hash, key| hash[key] = [] }

	# unless the first term in the array is an attribute, assume it is either a collection or object..begin sorting.
	unless @@word_buckets[0][@object_bucket][:attributes].include?(splat_vals[0])

		# reverse the array, as we are looking for the last collection to base from
		splat_vals.reverse!

		# grabs all the keys that are "collections", puts them in a list to compare to
		collection_words = @@word_buckets[0].values.collect {|obj_bucket| obj_bucket.values_at(:collections, :lists) }.flatten.compact.uniq
		
		# detect the first collection term in the reversed array
		collec1 = splat_vals.each_with_index.detect { |value,index| collection_words.include?(value) }

		# unless there was no collection specified, sort collections from objects from attributes based on the order they appear in the array
		unless collec1.nil?

			wordz = @@word_buckets[0][collec1[0].chop]
			obj_idx = 0
			col_idx = 0

			# anything after /:client/:object_bucket/:object follows this pattern;
			# /(collection|attribute)[0]/OBJECT[1]/(collection|attribute)[2]/OBJECT[3]/(collection|attribute)[4]...etc
			# attributes will have an even number index in the array, while the query OBJECT will have an odd index
			# e.g. /client/object_bucket/object/collection/object/collection/object/attribute/attribute would be
			# collection1/object2/  collection2  /object3/attribute1/attribute2 - where collection2 takes over as the base_ohm_object to draw attributes from
			splat_vals.values_at(collec1[1] + 1..-1).reverse.map.each_with_index do |value, index|
		 		index.odd? ? collections_objects["obj#{obj_idx += 1}".to_sym] = value : collections_objects["col#{col_idx += 1}".to_sym] = value
		 	end

			left_side = splat_vals.values_at(0..collec1[1])

			# the last element in the left_side array will be the last collection, which will be the base for anything after
			collections_objects["col#{col_idx += 1}".to_sym] = left_side.slice!(-1)
			
			# if the new last word in the array is an attribute, add to the final attribs hash_array. 
			# else, assume it is an object and everything after is an attribute
			if wordz[:attributes].include?(left_side.last)
				collections_objects[:attribs] = left_side
			else
				collections_objects["obj#{obj_idx += 1}".to_sym] = left_side.slice!(-1)
				collections_objects[:attribs] = left_side
			end

			# check to make sure all attrib terms are valid
			collections_objects[:attribs].each do |attrib|
				unless collections_objects[:attribs].empty?
					unless wordz[:attributes].include?(attrib)
						halt 402, "invalid attribute #{attrib}. select from #{wordz[:attributes]}" 
					end
				end
			end

			# check to make sure all collection words are valid
			collections_objects.select {|x| x =~ /col/}.each do |collection|
				unless collection_words.include?(collection[1])
					halt 402, "invalid collection #{collection}"
				end
			end

		end
		# remove any hash pair if value is nill as that just mucks everything up. 
		collections_objects.delete_if { |k,v| v.nil? }
		qbuilder(collections_objects)
		return @output

	end
	# regardless of anything, process any given attributes. make sure they are valid before sending to query builder
	splat_vals.each do |attrib|
		unless bucket_words.include?(attrib)
			halt 402, "invalid attribute #{attrib}... select from #{@@word_buckets[0][@object_bucket][:attributes]}"
		end
		collections_objects[:attribs] = splat_vals
	end
	qbuilder(collections_objects)
	return @output

end

	def get_something(*params)
		@output = params
		return @output
	end

end

#http://stackoverflow.com/a/15978603
set(:method) do |method|
	method = method.to_s.upcase
	condition { request.request_method == method }
end

# before processing request, check that input values (client, object_bucket, object, any additional attribs) are valid
# also, might as well set some vars while we're at it (@client, @object_bucket, @object, @splat_vals, @query_input)
before :method => :get do
	params = request.path_info.split('/')
	
	unless params[1].nil?
		@client = params[1]
		# query redis db for client info
		client = Client.find(name: @client).to_a[0]
		# todo: if client if specified, store the variable to connect to redis db here
		if client.nil?
			halt 402, {'Content-Type' => 'text/plain'}, "client \"#{params[1]}\" not found!!!"
		end
	end
	
	@object_bucket = params[2]
	
	# check if given object_bucket name is valid and that any additional attribs specified are valid
	unless @object_bucket.nil?

		all_words = @@word_buckets[0].values.collect { |x| x.values }.flatten.uniq

		# there is probably a better way to do this, but here we map alias names if used	
		if @object_bucket == 'vdc'
			@object_bucket = 'vdatacenter'
		elsif @object_bucket == 'vnet'
			@object_bucket = 'vnetwork'
		elsif @object_bucket == 'vds'
			@object_bucket = 'vdatastore'
		else		
			unless @@word_buckets[0].keys.include?(@object_bucket)
				halt 402, {'Content-Type' => 'text/plain'}, 
				"\"#{params[2]}\" is not a valid object_bucket, valid object_buckets include: #{@@word_buckets[0].keys.to_s}"
			end
		end
		
		# convert given object_bucket from a string into an actual ruby object http://stackoverflow.com/a/5924541
		# in this case a Ohm::Model object
		@ohm_ob = Object.const_get(@object_bucket.capitalize)

		unless params[3].nil?
			@object = params[3]
		end

		# set additional params to hash.
		unless params[4].nil?
			@splat_vals = params[4..-1]
		end

		# set query terms vars, check if given attributes are valid
		unless request.query_string.nil?
			@query_input = {}
			# split query string at '&' then do a regex match for each set provided (a set being ['foo=bar'])
			# capture values from regex then create hash with resulting values { attrib: term}
			request.query_string.split('&').each do |q|
				if match = q.match(/(\w+)=(\w+)/)
					attrib, term = match.captures
				end
				next if attrib.nil?
			@query_input[attrib.to_sym] = term
			end
			@query_input.keys.each { |k| halt 402, {'Content-Type' => 'text/plain'}, "#{k} is not a valid attribute" if !all_words.include?(k.to_s) }
		end

	end

end

# get list of available clients
get '/' do
	content_type :json
	output = Hash.new { |hash, key| hash[key] = [] }
	Client.all.map { |y| output['clients'] << y.attributes }
	JSON.pretty_generate(output)
end

# get list of object_buckets with basic attribs for a client
# todo: this is where we establish which redis db to use
get '/:client' do
	content_type :json
	output = {}
	output[params[:client]] = {
			VirtualDatacenters: Vdatacenter.all.count,
			Clusters: Cluster.all.count,
			Hosts: Host.all.count,
			VirtualNetworks: Vnetwork.all.count,
			VirtualDatastores: Vdatastore.all.count,
			VirtualMachines: Vm.all.count
		}
	JSON.pretty_generate(output)
end

get '/:client/:object_bucket' do
	content_type :json
	attribs = ['overallstatus', 'accessible', 'uuid']
	if @query_input.empty?
		@output = Hash.new { |hash, key| hash[key] = [] }
		@ohm_ob.all.find_all do |obj|
			@output[obj.name.to_sym] = obj.attributes.select {|atr| atr if attribs.include?(atr.to_s) }
		end
		JSON.pretty_generate(@output)
	else
		JSON.pretty_generate(get_something(@client, @object_bucket, @query_input))
	end
end

get '/:client/:object_bucket/:object' do
	content_type :json
	if @query_input.empty?
		# try to find object in the redis db by indexed name first, otherwise try a regex search
		# todo: account for attributes that need additional parsing (e.g. host sensors). also include any collection/list info
		output = Hash.new { |hash, key| hash[key] = [] }
		@ohm_ob.find(name: @object).select { |y| y.attributes.map {|z| output["#{z[0]}"] = z[1] } }

			if output.empty?
				output = @ohm_ob.all.find_all { |x| x.attributes[:name] =~ Regexp.new(@object) }.collect { |y| y.attributes }
				#output = @ohm_ob.all.select {|obj| obj.attributes if Regexp.new(@object) === obj.name}
				if output.empty?
					JSON.pretty_generate(["object #{@object} not found"])
				else
					JSON.pretty_generate(output)
				end	
			else
				JSON.pretty_generate(output)
			end
	else
		JSON.pretty_generate(get_something(@client, @object_bucket, @object, @query_input))
	end
end


get '/:client/:object_bucket/:object/*' do
	content_type :json
	JSON.pretty_generate(splat_sort(@splat_vals))

end