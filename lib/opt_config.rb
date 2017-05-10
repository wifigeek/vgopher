#!/usr/env/bin ruby
$:.push File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'yaml'
require 'util'
require 'data_collect'
require 'ohm_objects'

@@esxi_api_props = Hash.new { |hash, key| hash[key] = [] }
@@ohm_obj_buckets = Hash.new { |hash, key| hash[key] = [] }

class OptConfig

	#attr_accessor :client_config,:object_buckets

	CONFIG_DIR = File.expand_path(File.dirname(__FILE__) + '/../etc')

	def initialize
		@runtime_config = YAML.load_file File.join(CONFIG_DIR, "config.yml")		
	end
	
	def self.redis_db_setup
		new.redis_db_setup
	end

	def self.est_gateway
		new.est_gateway
	end

	def self.vc_tunnel(vc)
		new.vc_tunnel(vc)
	end

	# def self.test
	# 	new.test
	# end

	# def self.initialize
	# 	self.client_config = {}
	# 	self.object_buckets = {}
	# end
	def est_gateway
		GatewayJump::forward_gateway(@runtime_config['vcenter_tunnel']['gateway'], @runtime_config['vcenter_tunnel']['user'], @runtime_config['vcenter_tunnel']['password'])
	end

	def vc_tunnel(vc)
		GatewayJump::tunnel('vcenter', vc)
	end
	
	def redis_db_setup
		begin
		# connect to redis db # the corresponds with client # in config.ini
		Ohm.redis = Redic.new(@runtime_config['redis_stuff']['rsocketp'])
		
		@client = Client.create(name:  @runtime_config['redis_stuff']['name'])

		@runtime_config['datacenter'].keys.map do |vdc|
			Vdatacenter.create(name: "#{vdc}", client: @client, latestupdate: Time.now.to_i)
		end
		rescue Ohm::UniqueIndexViolation => fault
			logger.warn "#{fault}"
			exit
		end
	end


	def load_ohm_objects
		# find the config file for the specified client, load into var
		@object_buckets = YAML.load_file File.join(CONFIG_DIR, "object_buckets.yml")
		#@client_config = YAML.load_file File.join(CONFIG_DIR, "config.yml")

		# @object_buckets.each do |x|
		# 	@@esxi_api_props[x[0]] = x[1]['attribute'].select {|k,v| k if v != nil }.values
		# end

		@object_buckets.keys.map do |x|
			class_name = x.downcase.capitalize
			class_name = Ohm::Model
			#virtualmachine = Ohm::Model.new
		end

		


		# if @client_config.nil? || @object_buckets.nil?
		# 	puts "error error, config file not loaded proper"
		#  	exit
		# end
	end

	# def test

	# 	puts @client_config
	# 	puts @object_buckets

	# end

end

OptConfig.redis_db_setup
#puts @@ohm_obj_buckets
