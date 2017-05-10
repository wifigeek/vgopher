#!/usr/bin/env ruby
$:.push File.expand_path(File.dirname(__FILE__) + '/../lib')

require 'rbvmomi'
require 'util'
require 'fileutils'

# pull data from vcenter api, store data in redis
class VcenterConnect
include Logging

	def initialize
		@vms = {}
		@dvs = {}
		@dvpg = {}
		#network = {}
		@hosts = {}
		@clusters = {}
		@datastores = {}
		@datacenter = {}
		@folders = {}
	end

	def self.to_vcenter(vdc,vc,vc_user,vc_password)
		new.to_vcenter(vdc,vc,vc_user,vc_password)
	end
	# connect to the proper vcenter
	# can be cmd line arg e.g. get datastore info from isce1
	def to_vcenter(vdc,vc,vc_user,vc_password)
			@vdc1 = vdc
			@vc1 = vc.partition('.').shift.downcase
			@vc_results_output = File.join(@@json_results_dir, @vc1)
			FileUtils.mkdir(@vc_results_output) unless Dir.exists?(@vc_results_output)
			# create tunnel to vcenter server through the established gateway
			begin
			GatewayJump::tunnel('vcenter', vc)
			rescue => fault
				logger.warn "#{fault} - unable to connect to vcenter #{vc}"
			end

			begin
				@vim = RbVmomi::VIM.connect :host => '127.0.0.1', 
				:port => 2222, 
				:user => vc_user, 
				:password => vc_password, 
				:insecure => true
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

			#@pc = @vim.serviceContent.propertyCollector
			# start collection of data - vcenter_name is the short name
			# vcenter_name = vc.partition('.').shift.downcase
			#get_vcenter_data
			#GatewayJump::close_tunnel

	end

	def self.get_vcenter_data
		new.get_vcenter_data
	end

	# vcenter api call method
	def get_vcenter_data
		# properties to pull from managed data objects
		cluster_props = [ 'name', 'overallStatus', 'summary.effectiveCpu', 'summary.effectiveMemory', 'summary.numEffectiveHosts', 'summary.numHosts',
			'summary.totalCpu', 'summary.totalMemory', 'host' ]

		ds_props = [ 'name', 'summary.freeSpace', 'summary.capacity', 'summary.accessible', 'summary.url', 'host', 'vm' ]

		host_props = [ 'name', 'parent', 'overallStatus', 'summary.quickStats.overallCpuUsage', 
			'summary.quickStats.overallMemoryUsage', 'runtime.connectionState', 
			'runtime.powerState', 'runtime.healthSystemRuntime','config.network', 'config.service',
			'datastore', 'config.fileSystemVolume', 'summary.hardware.memorySize',
			'summary.runtime.inMaintenanceMode', 'hardware.biosInfo', 'summary.quickStats.uptime',
			'summary.hardware.model' ]

		vm_props = [ 'name', 'guest.ipAddress', 'guest.net', 'guest.disk', 'summary.overallStatus',
			'summary.config.vmPathName', 'config.locationId', 'summary.config.memorySizeMB', 'summary.config.numCpu',
			'summary.config.template', 'summary.guest.guestFullName', 'datastore', 'network', 'summary.runtime.host',
			'summary.runtime.powerState', 'storage.perDatastoreUsage', 'summary.storage.committed', 'summary.storage.uncommitted',
			'summary.storage.unshared', 'summary.guest.toolsVersionStatus2','summary.guest.toolsRunningStatus',
			'summary.quickStats.hostMemoryUsage','summary.quickStats.guestMemoryUsage','summary.quickStats.balloonedMemory',
			'summary.quickStats.uptimeSeconds', 'summary.guest.ipAddress' ]

			# 'storage.timestamp', 'summary.quickStats', 'summary.runtime.device', 'summary.guest.hostName', 'summary.guest.ipAddress',
			# 'guest.net.macAddress', 'guest.net.network', 'layoutEx', 'summary.config.instanceUuid', 'config.datastoreUrl', 'summary.runtime.cleanPowerOff',
			# 'summary.runtime.consolidationNeeded',

		propSet = [{ :type => 'VirtualMachine', :pathSet => vm_props }]

		logger.info "gathering info from #{@vc1} based on filterSpec"

		filterSpec = RbVmomi::VIM::PropertyFilterSpec(
			:objectSet => [
				:obj => @vim.serviceInstance.content.rootFolder, 
				:selectSet => [
					
					# traverse root folder
					RbVmomi::VIM.TraversalSpec(
						:name => 'tsFolder',
						:type => 'Folder', 
						:path => 'childEntity',
						:skip => 'false',
						:selectSet => [
							RbVmomi::VIM.SelectionSpec(:name => 'tsFolder'),
							RbVmomi::VIM.SelectionSpec(:name => 'tsDatacenterVmFolder'),
							RbVmomi::VIM.SelectionSpec(:name => 'tsDatacenterHostFolder'),
							RbVmomi::VIM.SelectionSpec(:name => 'tsDatacenterNetworkFolder'),
							RbVmomi::VIM.SelectionSpec(:name => 'tsDatacenterdatastoreFolder'),
							RbVmomi::VIM.SelectionSpec(:name => 'tsClusterHost')
						]
						),
					
					# traverse through vmfolder
					RbVmomi::VIM.TraversalSpec(
						:name => 'tsDatacenterVmFolder',
						:type =>'Datacenter',
						:path => 'vmFolder',
						:skip => 'false',
						:selectSet => [
							RbVmomi::VIM.SelectionSpec(:name => 'tsFolder')
						]
						),

					# traverse through hostFolder
					RbVmomi::VIM.TraversalSpec(
						:name => 'tsDatacenterHostFolder',
						:type =>'Datacenter',
						:path => 'hostFolder',
						:skip => 'false',
						:selectSet => [
							RbVmomi::VIM.SelectionSpec(:name => 'tsFolder')
						]
						),

					# traverse through dataStore folder
					RbVmomi::VIM.TraversalSpec(
						:name => 'tsDatacenterdatastoreFolder',
						:type =>'Datacenter',
						:path => 'datastoreFolder',
						:skip => 'false',
						:selectSet => [
							RbVmomi::VIM.SelectionSpec(:name => 'tsFolder')
						]
						),

					# traverse hosts by cluster
					RbVmomi::VIM.TraversalSpec(
						:name => 'tsClusterHost',
						:type => 'ComputeResource',
						:path => 'host',
						:skip => 'false',
						:selectSet => [
						]
						),

					# traverse network folder
					RbVmomi::VIM.TraversalSpec(
						:name => 'tsDatacenterNetworkFolder',
						:type => 'Datacenter',
						:path => 'networkFolder',
						:skip => 'false',
						:selectSet => [
							RbVmomi::VIM.SelectionSpec(:name => 'tsFolder')
						]
						),

				]

			],
			# declare properties we want to retrieve from each object type
			:propSet => [
				{ :type => 'VirtualMachine', :pathSet => vm_props, :all => false  },
				{ :type => 'Datastore', :pathSet => ds_props },
				{ :type => 'HostSystem', :pathSet => host_props },
				{ :type => 'ComputeResource', :pathSet => cluster_props },
				# { :type => 'Datacenter', :pathSet => ['name'] },
				# { :type => 'Folder', :pathSet => ['name', 'parent'] },
				{ :type => 'DistributedVirtualSwitch', :pathSet => ['name', 'uuid', 'summary', 'runtime'] },
				{ :type => 'DistributedVirtualPortgroup', :pathSet => ['name', 'key', 'summary'] }
			]
		)


		@timestamp = Time.now.to_i

		results = @vim.propertyCollector.RetrieveProperties(:specSet => [filterSpec])

		logger.info "results retrieved, sorting..."

		# @vms = {}
		# @dvs = {}
		# @dvpg = {}
		# #network = {}
		# @hosts = {}
		# @clusters = {}
		# @datastores = {}
		# @datacenter = {}
		# @folders = {}
 
		# this will produce a hash with the obj being the key, and the properties being the value
		# todo: consider using case/when statement here
		results.each do |data|
			if data.obj.is_a?(RbVmomi::VIM::VirtualMachine)
				@vms[data.obj] = data.to_hash
			elsif data.obj.is_a?(RbVmomi::VIM::DistributedVirtualSwitch)
				@dvs[data.obj] = data.to_hash
			elsif data.obj.is_a?(RbVmomi::VIM::DistributedVirtualPortgroup)
				@dvpg[data.obj] = data.to_hash
			# elsif data.obj.is_a?(RbVmomi::VIM::Network)
			# 	@network[data.obj] = data.to_hash
			elsif data.obj.is_a?(RbVmomi::VIM::HostSystem)
				@hosts[data.obj] = data.to_hash
			elsif data.obj.is_a?(RbVmomi::VIM::ComputeResource)
				@clusters[data.obj] = data.to_hash
			elsif data.obj.is_a?(RbVmomi::VIM::Datastore)
				@datastores[data.obj] = data.to_hash
			# elsif data.obj.is_a?(RbVmomi::VIM::Datacenter)
			# 	@datacenter[data.obj] = data.to_hash
			# elsif data.obj.is_a?(RbVmomi::VIM::Folder)
			# 	@folders[data.obj] = data.to_hash			
			end
		end

		# send sorted results to redis store method #build_tree
		#build_tree(@dvpg, @dvs, @datastores, @clusters, @hosts, @vms, @vcenter_name)
		# dvs_output
		# virt_machine_output
		# hostsystem_output
		# cluster_output
		# datastore_output


	end

	def dvs_output
		output = Hash.new { |hash, key| hash[key] = [] }
		output['timestamp'] = @timestamp
		@dvs.values.map do |vss|
			output[vss['name'].downcase] = { 
				:uuid => vss['uuid'],
				:portgroups => vss['summary'][:portgroupName],
				:vcenter => @vc1,
				:vdatacenter => @vdc1
			}
		end
		File.open(File.join(@vc_results_output, "#{@vc1}_Vnetwork.json"), "w") do |f|
			f.write(JSON.pretty_generate(output))
		end

	end

	def datastore_output
		output = Hash.new { |hash, key| hash[key] = [] }
		output['timestamp'] = @timestamp
		@datastores.values.map do |ds|
			output[ds['name'].downcase] = {
				:capacity => ds['summary.capacity'],
				:free => ds['summary.freeSpace'],
				:used => (ds['summary.capacity'] - ds['summary.freeSpace']),
				#:pct_used => (ds['summary.capacity'].to_i - ds['summary.freeSpace'].to_i) * 100 / ds['summary.capacity'].to_i,
				:url => ds['summary.url'],
				:accessible => ds['summary.accessible'],
				:vcenter => @vc1,
				:vdatacenter => @vdc1
			}
		end

		File.open(File.join(@vc_results_output, "#{@vc1}_Vdatastore.json"), "w") do |f|
			f.write(JSON.pretty_generate(output))
		end

	end

	def cluster_output
		output = Hash.new { |hash, key| hash[key] = [] }
		output['timestamp'] = @timestamp
		@clusters.values.map do |cluster|
			output[cluster['name'].downcase] = {
				:overallstatus => cluster['overallStatus'],
				:effectivecpu => cluster['summary.effectiveCpu'],
				:effectivememory => cluster['summary.effectiveMemory'],
				:numeffectivehosts => cluster['summary.numEffectiveHosts'],
				:numhosts => cluster['summary.numHosts'],
				:totalcpu => cluster['summary.totalCpu'],
				:totalmemory => cluster['summary.totalMemory'],
				:vcenter => @vc1,
				:vdatacenter => @vdc1
				}
		end

		File.open(File.join(@vc_results_output, "#{@vc1}_Cluster.json"), "w") do |f|
			f.write(JSON.pretty_generate(output))
		end

	end

	def hostsystem_output
		output = Hash.new { |hash, key| hash[key] = [] }
		output['timestamp'] = @timestamp
	    @hosts.values.each do |cnode|
			# get the cluster object associated with this host
			#cluster_name = clusters.values_at(cnode['parent'])[0]['name']
			clusta = @clusters.values_at(cnode['parent'])[0]['name'].downcase

			# create a new hash with the key being sensorType and the value an array of sensor values
			host_sensor_values = Hash.new { |hash, key| hash[key] = [] }
			cnode['runtime.healthSystemRuntime'][:systemHealthInfo][:numericSensorInfo].collect do |x|
				host_sensor_values[x.name.to_sym] = x.healthState.props.map {|k,v| {k.to_s.to_sym => v} unless k.to_s =~ /dynamicProperty/ }.compact
				host_sensor_values[x.name.to_sym] << x.props.map {|k,v| {k.to_s.to_sym => v} if k.to_s =~ /currentReading|baseUnits|sensorType/ }.compact
			end
			
			# host services. get name, runlevel option, current status (:running is boolean)
			host_services = Hash.new { |hash, key| hash[key] = [] }

			cnode['config.service'][:service].select do |x| 
				host_services[x.key] = x.props.map {|k,v| {k.to_s.to_sym => v} if k.to_s =~ /label|policy|running/ }.compact
			end

			host_filesystems = Hash.new { |hash, key| hash[key] = [] }

			cnode['config.fileSystemVolume'][:mountInfo].collect do |x|
				host_filesystems[x.mountInfo.path] = x.mountInfo.props.map {|k,v| {k.to_s.to_sym => v} unless k.to_s =~ /dynamicProperty/ }.compact
				host_filesystems[x.mountInfo.path] = x.volume.props.map {|k,v| {k.to_s.to_sym => v} unless k.to_s =~ /dynamicProperty|extent/ }.compact
			end
			
			route_info = {}
			route_info = cnode['config.network'][:dnsConfig].props.map do |r|
				{r[0] => r[1]} if r[0].to_s =~ /domainName|address|searchDomain/
			end.compact

			biosinfo = {}
			biosInfo = cnode['hardware.biosInfo'].props.map do |b|
				{b[0] => b[1]} unless b[0].to_s =~ /dynamicProperty/
			end.compact
			
			vnic_output = Hash.new { |hash, key| hash[key] = [] }
			begin
			cnode['config.network'][:vnic].map do |vnic|
				vnic_output[vnic.device.to_sym] = { 
					:portkey => vnic.spec.distributedVirtualPort.portKey, 
					:portgroupkey => vnic.spec.distributedVirtualPort.portgroupKey, 
					:switchuuid => vnic.spec.distributedVirtualPort.switchUuid, 
					:ipaddress => vnic.spec.ip.ipAddress, 
					:subnet => vnic.spec.ip.subnetMask, 
					:mtu => vnic.spec.mtu
				}
			end
			rescue => fault
				logger.warn "#{fault} - #{cnode['name']} be havin a problem with vnics"
			end
			h1_name = cnode['name'].partition('.').shift.downcase
			h1_domain = cnode['name'].partition('.').pop.downcase
			# create new host entry in redis

			output[h1_name] = {
				:domain => h1_domain,
				:overallstatus => cnode['overallStatus'],
				:overallcpuusage => cnode['summary.quickStats.overallCpuUsage'],
				:overallmemoryusage => cnode['summary.quickStats.overallMemoryUsage'],
				:totalmemory => cnode['summary.hardware.memorySize'],
				:powerstate => cnode['runtime.powerState'],
				:connectionstate => cnode['runtime.connectionState'],
				:uptime => cnode['summary.quickStats.uptime'],
				:inmaintenancemode => cnode['summary.runtime.inMaintenanceMode'],
				:hardwaremodel => cnode['summary.hardware.model'],
				:vnics => vnic_output,
				:biosinfo => biosinfo,
				:cluster => clusta,
				:vcenter => @vc1,
				:vdatacenter => @vdc1,
				:filesystems => host_filesystems,
				:services => host_services, 
				:sensors => host_sensor_values,
				:route_info => route_info
			}

		end

		File.open(File.join(@vc_results_output, "#{@vc1}_Host.json"), "w") do |f|
			f.write(JSON.pretty_generate(output))
		end
	end

	def virt_machine_output
		output = Hash.new { |hash, key| hash[key] = [] }
		output['timestamp'] = @timestamp
		@vms.values.each do |vm|
			begin
			# if vm is a template, create a new object in redis, noting it is a template. then go to the next vm data object
			if vm['summary.config.template'] == true
				output[vm['name'].downcase] = { vdatacenter: @vdc1, template: 'true' }
				next
			end

			# get the host and cluster the vm belongs to
			esx_host_fqdn = @hosts.values_at(vm['summary.runtime.host'])[0]['name']
			esx_host_name = esx_host_fqdn.partition('.')[0].downcase
			
			vmhost = esx_host_name
			#vmcluster = Cluster[vmhost.cluster_id.to_i]

			# get the portgroup the vm is in. portgroup is an indexed attribute of a Vnetwork(vswitch) object bucket
			portgroup = @dvpg.values_at(vm['network'][0])[0]['name']
			#vmnet = Vnetwork.find(portgroup: portgroup).to_a[0]
			
			# calculate the total provisioned storage for the vm
			# unless vm['summary.storage.uncommitted'].nil? || vm['summary.storage.committed'].nil?
			# 	provisionedstorage = vm['summary.storage.uncommitted'] + vm['summary.storage.committed']
			# end

			rescue => exc
				if portgroup.nil?
					logger.warn "#{exc} - #{vm['name'].downcase} is not assigned to a portgroup"
				else
					logger.warn "#{exc} - #{vm['name'].downcase} is f-ed up. check it"
				end
			end

			guestdisk = Hash.new { |hash, key| hash[key] = [] }
			vm['guest.disk'].collect {|disk| disk.props}.map {|disk_props| guestdisk[disk_props[:diskPath].to_sym] << disk_props[:freeSpace] << disk_props[:capacity] }
			
			# create a new vm entry in redis
			output[vm['name'].downcase] = {
				:name => vm['name'].downcase,
				:overallstatus => vm['summary.overallStatus'],
				:numcpu => vm['summary.config.numCpu'],
				:memoryallocated => vm['summary.config.memorySizeMB'],
				:hostmemoryusage => vm['summary.quickStats.hostMemoryUsage'],
				:guestmemoryusage => vm['summary.quickStats.guestMemoryUsage'],
				:balloonedmemory => vm['summary.quickStats.balloonedMemory'],
				:ipaddr => vm['summary.guest.ipAddress'],
				:os => vm['summary.guest.guestFullName'],
				:vmwaretools_status => vm['summary.guest.toolsRunningStatus'],
				:vmwaretools_version => vm['summary.guest.toolsVersionStatus2'],
				:powerstate => vm['summary.runtime.powerState'],
				:uptime => vm['summary.quickStats.uptimeSeconds'],
				:guestdisk => guestdisk,
				:host => vmhost,
				:locationid => vm['config.locationId'],
				:portgroup => portgroup,
				:vcenter => @vc1,
				:vdatacenter => @vdc1,
				:usedstorage => vm['summary.storage.committed'],
				:unsharedstorage => vm['summary.storage.unshared'],
			}
		end
		File.open(File.join(@vc_results_output, "#{@vc1}_Vm.json"), "w") do |f|
			f.write(JSON.pretty_generate(output))
		end
	end

	def output
		dvs_output
		virt_machine_output
		hostsystem_output
		cluster_output
		datastore_output
	end


	# populate the redis store with vcenter api data
	def build_tree(dvpg, dvs, datastores, clusters, hosts, vms, vcenter_name)
		logger.debug "filling dvs values"
		dvs.values.each do |vss|
			#portgroups = vss['summary'][:portgroupName].map {|name| name.downcase}
			begin
			dvs1 = Vnetwork.create(
				:name => vss['name'].downcase,
				:uuid => vss['uuid'],
				:portgroups => vss['summary'][:portgroupName],
				:vcenter => vcenter_name,
				:vdatacenter => @vdc1
				)
			rescue Ohm::UniqueIndexViolation => fault
				dvs1_id = Vnetwork.find(uuid: vss['uuid']).to_a[0]
				logger.warn "#{fault} - #{vss['name'].downcase} already exists with id: #{dvs1_id.id}"
				next
			end

		end

		logger.debug "filling datastore values"
		datastores.values.each do |ds|
			status = "accessible = #{ds['summary.accessible']}"
			begin
			ds1 = Vdatastore.create(
				:name => ds['name'].downcase,
				:capacity => ds['summary.capacity'],
				:free => ds['summary.freeSpace'],
				:used => (ds['summary.capacity'] - ds['summary.freeSpace']),
				#:pct_used => (ds['summary.capacity'].to_i - ds['summary.freeSpace'].to_i) * 100 / ds['summary.capacity'].to_i,
				:url => ds['summary.url'],
				:accessible => ds['summary.accessible'],
				:vcenter => vcenter_name,
				:vdatacenter => @vdc1
				)
			rescue Ohm::UniqueIndexViolation => fault
				ds1_id = Vdatastore.find(name: ds['name'].downcase).to_a[0]
				logger.warn "#{fault} - #{ds['name'].downcase} already exists with id: #{ds1_id.id}"
				next
			end
		end

		logger.debug "filling cluster values"
		clusters.values.each do |cluster|
			begin
			c1 = Cluster.create(
				:name => cluster['name'].downcase,
				:overallstatus => cluster['overallStatus'],
				:effectivecpu => cluster['summary.effectiveCpu'],
				:effectivememory => cluster['summary.effectiveMemory'],
				:numeffectivehosts => cluster['summary.numEffectiveHosts'],
				:numhosts => cluster['summary.numHosts'],
				:totalcpu => cluster['summary.totalCpu'],
				:totalmemory => cluster['summary.totalMemory'],
				:vcenter => vcenter_name,
				:vdatacenter => @vdc1
				)
			rescue Ohm::UniqueIndexViolation => fault
				c1_id = Cluster.find(name: cluster['name'].downcase).to_a[0]
				logger.warn "#{fault} - #{cluster['name'].downcase} already exists with id: #{c1_id.id}"
				next
			end
		end

		logger.debug "filling host values"
		hosts.values.each do |cnode|
			# get the cluster object associated with this host
			#cluster_name = clusters.values_at(cnode['parent'])[0]['name']
			clusta = Cluster.find(name: clusters.values_at(cnode['parent'])[0]['name'].downcase).to_a[0]

			# create a new hash with the key being sensorType and the value an array of sensor values
			host_sensor_values = Hash.new { |hash, key| hash[key] = [] }
			cnode['runtime.healthSystemRuntime'][:systemHealthInfo][:numericSensorInfo].collect do |x|
				host_sensor_values[x.name.to_sym] = x.healthState.props.map {|k,v| {k.to_s.to_sym => v} unless k.to_s =~ /dynamicProperty/ }.compact
				host_sensor_values[x.name.to_sym] << x.props.map {|k,v| {k.to_s.to_sym => v} if k.to_s =~ /currentReading|baseUnits|sensorType/ }.compact
			end
			
			# host services. get name, runlevel option, current status (:running is boolean)
			host_services = Hash.new { |hash, key| hash[key] = [] }

			cnode['config.service'][:service].select do |x| 
				host_services[x.key] = x.props.map {|k,v| {k.to_s.to_sym => v} if k.to_s =~ /label|policy|running/ }.compact
			end

			host_filesystems = Hash.new { |hash, key| hash[key] = [] }

			cnode['config.fileSystemVolume'][:mountInfo].collect do |x|
				host_filesystems[x.mountInfo.path] = x.mountInfo.props.map {|k,v| {k.to_s.to_sym => v} unless k.to_s =~ /dynamicProperty/ }.compact
				host_filesystems[x.mountInfo.path] = x.volume.props.map {|k,v| {k.to_s.to_sym => v} unless k.to_s =~ /dynamicProperty|extent/ }.compact
			end
			
			route_info = {}
			route_info = cnode['config.network'][:dnsConfig].props.map do |r|
				{r[0] => r[1]} if r[0].to_s =~ /domainName|address|searchDomain/
			end.compact

			biosinfo = {}
			biosInfo = cnode['hardware.biosInfo'].props.map do |b|
				{b[0] => b[1]} unless b[0].to_s =~ /dynamicProperty/
			end.compact
			
			vnic_output = Hash.new { |hash, key| hash[key] = [] }
			begin
			cnode['config.network'][:vnic].map do |vnic|
				vnic_output[vnic.device.to_sym] = { 
					:portkey => vnic.spec.distributedVirtualPort.portKey, 
					:portgroupkey => vnic.spec.distributedVirtualPort.portgroupKey, 
					:switchuuid => vnic.spec.distributedVirtualPort.switchUuid, 
					:ipaddress => vnic.spec.ip.ipAddress, 
					:subnet => vnic.spec.ip.subnetMask, 
					:mtu => vnic.spec.mtu
				}
			end
			rescue => fault
				logger.warn "#{fault} - #{cnode['name']} be havin a problem with vnics"
			end
			h1_name = cnode['name'].partition('.').shift.downcase
			h1_domain = cnode['name'].partition('.').pop.downcase
			# create new host entry in redis
			begin
			h1 = Host.create(
				:name => h1_name,
				:domain => h1_domain,
				:overallstatus => cnode['overallStatus'],
				:overallcpuusage => cnode['summary.quickStats.overallCpuUsage'],
				:overallmemoryusage => cnode['summary.quickStats.overallMemoryUsage'],
				:totalmemory => cnode['summary.hardware.memorySize'],
				:powerstate => cnode['runtime.powerState'],
				:connectionstate => cnode['runtime.connectionState'],
				:uptime => cnode['summary.quickStats.uptime'],
				:inmaintenancemode => cnode['summary.runtime.inMaintenanceMode'],
				:hardwaremodel => cnode['summary.hardware.model'],
				:vnics => vnic_output,
				:biosinfo => biosinfo,
				:cluster => clusta,
				:vcenter => vcenter_name,
				:vdatacenter => @vdc1,
				:filesystems => host_filesystems,
				:services => host_services, 
				:sensors => host_sensor_values,
				:route_info => route_info
				)
			rescue Ohm::UniqueIndexViolation => fault
				h1_id = Host.find(name: h1_name).to_a[0]
				logger.warn "#{fault} - #{cnode['name'].downcase} already exists with id: #{h1_id.id}"
				next
			end

			# add attached vnetworks to the list within host object
			cnode['config.network'][:proxySwitch].each do |network|
				dvs1 = Vnetwork.find(name: network.dvsName.downcase).to_a[0]
				h1.vnetworks.push(dvs1)
				network[:spec][:backing][:pnicSpec].each do |spec|
					h1.update(pnics: [ spec.pnicDevice, spec.uplinkPortgroupKey ])
				end
				dvs1.hosts.push(h1)
			end

			# add attached datastores to the list within Host object
			ds_names = []
			cnode['datastore'].each do |ds|
				ds_names << datastores.values_at(ds)[0]['name'].downcase
			end
			ds_names.each do |_ds|
				vds1 = Vdatastore.find(name: _ds).to_a[0]
				h1.vdatastores.push(vds1)
				vds1.hosts.push(h1)
			end

		end

		logger.debug "filling vms values"
		vms.values.each do |vm|
			begin
			# if vm is a template, create a new object in redis, noting it is a template. then go to the next vm data object
			if vm['summary.config.template'] == true
				vm_tmpla = Vm.create(name: vm['name'].downcase, vdatacenter: @vdc1, template: 'true')
				next
			end

			# get the host and cluster the vm belongs to
			esx_host_fqdn = hosts.values_at(vm['summary.runtime.host'])[0]['name']
			esx_host_name = esx_host_fqdn.partition('.')[0].downcase
			
			vmhost = Host.find(name: esx_host_name).to_a[0]
			vmcluster = Cluster[vmhost.cluster_id.to_i]

			# get the portgroup the vm is in. portgroup is an indexed attribute of a Vnetwork(vswitch) object bucket
			portgroup = dvpg.values_at(vm['network'][0])[0]['name']
			vmnet = Vnetwork.find(portgroup: portgroup).to_a[0]
			
			# calculate the total provisioned storage for the vm
			unless vm['summary.storage.uncommitted'].nil? || vm['summary.storage.committed'].nil?
				provisionedstorage = vm['summary.storage.uncommitted'] + vm['summary.storage.committed']
			end

			rescue => exc
				if portgroup.nil?
					logger.warn "#{exc} - #{vm['name'].downcase} is not assigned to a portgroup"
				else
					logger.warn "#{exc} - #{vm['name'].downcase} is f-ed up. check it"
				end
			end

			guestdisk = Hash.new { |hash, key| hash[key] = [] }
			vm['guest.disk'].collect {|disk| disk.props}.map {|disk_props| guestdisk[disk_props[:diskPath].to_sym] << disk_props[:freeSpace] << disk_props[:capacity] }
			
			# create a new vm entry in redis
			begin
			vm1 = Vm.create(
				:name => vm['name'].downcase,
				:overallstatus => vm['summary.overallStatus'],
				:numcpu => vm['summary.config.numCpu'],
				:memoryallocated => vm['summary.config.memorySizeMB'],
				:hostmemoryusage => vm['summary.quickStats.hostMemoryUsage'],
				:guestmemoryusage => vm['summary.quickStats.guestMemoryUsage'],
				:balloonedmemory => vm['summary.quickStats.balloonedMemory'],
				:ipaddr => vm['summary.guest.ipAddress'],
				:os => vm['summary.guest.guestFullName'],
				:vmwaretools_status => vm['summary.guest.toolsRunningStatus'],
				:vmwaretools_version => vm['summary.guest.toolsVersionStatus2'],
				:powerstate => vm['summary.runtime.powerState'],
				:uptime => vm['summary.quickStats.uptimeSeconds'],
				:guestdisk => guestdisk,
				:host => vmhost,
				:cluster => vmcluster,
				:locationid => vm['config.locationId'],
				:vnetwork => vmnet,
				:vcenter => vcenter_name,
				:vdatacenter => @vdc1,
				:usedstorage => vm['summary.storage.committed'],
				:provisionedstorage => provisionedstorage,
				:unsharedstorage => vm['summary.storage.unshared'],
				)
			rescue Ohm::UniqueIndexViolation => fault
				vm1_id = Vm.find(locationid: vm['summary.config.locationId']).to_a[0]
				logger.warn "#{fault} - #{vm['name'].downcase} already exists with id: #{vm1_id.id} - #{vm1_id.name}"
				next
			end

			# add attached datastores to the list within Vdatastore object
			begin
			ds_names = []
			vm['datastore'].each do |vm_ds|
				ds_names << datastores.values_at(vm_ds)[0]['name'].downcase
			end
			ds_names.each do |d|
				vmds_id = Vdatastore.find(name: d).to_a[0]
				vm1.vdatastores.push(vmds_id)
				vmds_id.vms.push(vm1)
			end
			rescue => fault
				logger.warn "#{fault} - #{vm['name'].downcase} datastore_id not present"
			end

		end



	end



end #class end
