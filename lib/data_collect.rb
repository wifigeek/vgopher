#!/usr/bin/env ruby
CONFIG_DIR = File.expand_path(File.dirname(__FILE__) + '/../etc')

class DataCollect

	def initialize
		@runtime_config = YAML.load_file File.join(CONFIG_DIR, "config.yml")
		@vchost = @runtime_config['vcenter_tunnel']['localhost']
		@vcport = @runtime_config['vcenter_tunnel']['port']
		@vcuser = @runtime_config['vcenter_auth']['user']
		@vcpassword = @runtime_config['vcenter_auth']['password']
	end

	def self.connect_to_vc
		new.connect_to_vc
	end

	def connect_to_vc
			begin
				@vim = RbVmomi::VIM.connect :host => @vchost, :port => @vcport, :user => @vcuser, :password => @vcpassword, :insecure => true
			rescue => exc
				p exc
				logger.error(exc)
				exit
			end

			begin
				#@root_folder = @vim.serviceInstance.content.rootFolder
				@dc = @vim.serviceInstance.find_datacenter
			rescue => exc
				p exc
				logger.error(exc)
				exit
			end
	end




end