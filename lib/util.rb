#!/usr/bin/env ruby
# this file contains modules used throughout the app. ideally these can be called as standalone instances
# http://www.intridea.com/blog/2010/4/19/ruby-quick-tip-instant-utility-modules

# module to create ssh tunnel as needed
module GatewayJump
	module_function

	require 'net/ssh'
	require 'net/ssh/gateway'

	def forward_gateway(gateway_host, user, pass)

		@gateway = Net::SSH::Gateway.new(gateway_host, user, :password => pass, :timeout => 10)

	end

	def tunnel(type, dst_host)
		#logger.info "establishing #{type} tunnel to #{dst_host}"
	  # todo: make it so multiple tunnels can run. or at least retry a different port instead of error
		case type
		when 'puppet'
  		@port = @gateway.open(dst_host, 8080,2222)
		when 'ipadmin_util'
  		@port = @gateway.open(dst_host, 2222,2222)
		when 'db'
  		@port = @gateway.open(dst_host, 3306,2222)
		when 'vcenter'
  		@port = @gateway.open(dst_host, 443,2222)
		end
	
  end

	#close tunnel connection
	def close_tunnel

  	@gateway.close(@port)

	end

	#close gateway connection
	def close_gateway

  	@gateway.shutdown!

	end

end

# module to load yaml config file and decrypt encrypted passwords with symmetric gem
# module YAMLConfigBase
# 	module_function

# 	require 'yaml'
# 	require 'symmetric-encryption'

#   def configure(yml_file)

#     #config = YAML::load(File.open(yml_file))
#     symmetric_config = File.join(LIB_DIR, '.keys', '.symmetric.yml')
#     SymmetricEncryption.load!(symmetric_config, 'production')
#     config = YAML.load(ERB.new(File.new(yml_file).read).result)
#       parse_config config

#   end
  
#   def parse_config(config)

#     config.each do |key, value|
#       setter = "#{key}="
#       self.class.send(:attr_accessor, key) if !respond_to?(setter)
#       send setter, value
#     end

#   end
  
# end

# module for log format
module Logging
	module_function

	require 'logger'
  
  @loggers = {}

  def logger
    
    classname = self.class.name
    methodname = caller[0][/`([^']*)'/, 1]
    @logger ||= Logging.logger_for(classname, methodname)
    @logger.progname = "#{classname}\##{methodname}"
    @logger

  end

  class << self

    def get_log_level

      test = Logger::DEBUG
      test

    end

    def logger_for(classname, methodname)

      @loggers[classname] ||= configure_logger_for(classname, methodname)

    end

    def configure_logger_for(classname, methodname)

      current_date = Time.now.strftime('%Y-%m-%d')
      log_file = File.join(LOG_DIR, "esxi-#{current_date}.log")
      logger = Logger.new(log_file, LOG_MAX_FILES, LOG_MAX_SIZE)
      logger.level = get_log_level
      logger
      
    end

  end

end


LOG_DIR = File.expand_path(File.dirname(__FILE__) + '/logs')
LOG_LEVEL = Logger::DEBUG
LOG_MAX_SIZE = 6145728
LOG_MAX_FILES = 10