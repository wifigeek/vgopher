#!/usr/bin/env ruby
$:.push File.expand_path(File.dirname(__FILE__) + '/../lib')

# start here. select runtime options, set initital vars

require 'optparse'
require 'iniparse'

require 'vc_collect2'
require 'util'
require 'ohm_objects'

CONFIG_DIR = File.expand_path(File.dirname(__FILE__) + '/../clients')

DATA_DIR = File.expand_path(File.dirname(__FILE__) + '/../data')

client_list = Dir.open(CONFIG_DIR).collect {|dir| dir unless dir == "." || dir == ".."}.compact

@options = {:client => false}

OptionParser.new do |opts|
	opts.banner = "usage: vgopher.rb [options]"

	opts.on("-c", "--client [CLIENT]", "select client to connect to") do |client|
		@options[:client] = client
	end

	opts.on("-l", "--list-clients", "list available clients") do
		puts client_list
		exit
	end

	opts.on("-h", "--help", 'Displays Help') do
		puts opts
		exit
	end
end.parse!

def set_vars(options)
	unless !@options[:client].empty?
		puts "unable to load client config for: #{@options[:client]}"
	end

	# load client config_file
	@runtime_config = IniParse.parse( File.read(File.join(CONFIG_DIR, @options[:client], 'config.ini')) )
end

def redis_db_setup
	begin
	# connect to redis db # the corresponds with client # in config.ini
	Ohm.redis = Redic.new(@runtime_config[:redisdb][:rsocketp])
	
	@client = Client.create(name:  @runtime_config[:redisdb][:name])

	@runtime_config[:vcenters].lines.keys.map do |vdc|
		Vdatacenter.create(name: "#{vdc}", client: @client, latestupdate: Time.now.to_i)
	end
	rescue Ohm::UniqueIndexViolation => fault
		logger.warn "#{fault}"
		exit
	end
end

def tunnelvc
	# make call to sf_firewall before here
	GatewayJump::forward_gateway(
		@runtime_config['gateway']['host'], 
		@runtime_config['gateway']['ip_user'], 
		@runtime_config['gateway']['ip_password']
		)
end



def get_vcenter_data(vdc,vc)
	# todo: reconfigure to account that a gateway/tunnel may not be needed
	# vchost = @runtime_config['vc_connect_info']['ip']
	# port = @runtime_config['vc_connect_info']['port']
	vc_password = @runtime_config['vc_connect_info']['vc_password']
	vc_user = @runtime_config['vc_connect_info']['vc_user']

	connect = VcenterConnect.new

	#vdc1 = Vdatacenter.find(name: vdc1).first
	connect.to_vcenter(vdc,vc,vc_user,vc_password)
	connect.get_vcenter_data
	connect.dvs_output
	connect.virt_machine_output
	connect.hostsystem_output
	connect.cluster_output
	connect.datastore_output
	#vcenter_name = vc.partition('.').shift.downcase
	
	#connect.get_vcenter_data
	#vdc1.update(latestupdate: Time.now.to_i)
	GatewayJump::close_tunnel
	connect = []

end




set_vars(@options)
#redis_db_setup
tunnelvc
@@json_results_dir = File.join(DATA_DIR, Time.now.to_i.to_s)	
FileUtils.mkdir(@@json_results_dir) unless Dir.exists?(@@json_results_dir)
@runtime_config[:vcenters].each do |datacenter|
	datacenter.each do |dc_vc|
		get_vcenter_data(dc_vc.key, dc_vc.value)
	end
end
#get_vcenter_data('isce_test', 'vcsa3t1.test.syncopatedtech.com')
GatewayJump::close_gateway

