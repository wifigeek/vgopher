#!/usr/bin/env ruby
require 'ohm'
require 'ohm/contrib'

# Client object_bucket
class Client < Ohm::Model
	attribute :name
	collection :vdatacenters, :Vdatacenter
	unique :name
	index :name
end

# Data Center object_bucket
class Vdatacenter < Ohm::Model
	attribute :name
	attribute :latestupdate
	collection :clusters, :Cluster
	collection :hosts, :Host
	collection :vnetworks, :Vnetwork
	collection :vdatastores, :Vdatastore
	collection :vms, :Vm
	reference :client, :Client
	index :name
end

# Cluster object_bucket
class Cluster < Ohm::Model
	attribute :name
	attribute :overallstatus
	attribute :effectivecpu
	attribute :effectivememory
	attribute :numeffectivehosts
	attribute :numhosts
	attribute :totalcpu
	attribute :totalmemory
	attribute :vcenter
	collection :hosts, :Host
	collection :vms, :Vm
	reference :vdatacenter, :Vdatacenter
	unique :name
	index :name
end

# Host object_bucket
class Host < Ohm::Model
	include Ohm::DataTypes

	attribute :name
	attribute :domain
	attribute :overallstatus
	attribute :overallcpuusage
	attribute :overallmemoryusage
	attribute :totalmemory
	attribute :powerstate
	attribute :connectionstate
	attribute :inmaintenancemode
	attribute :biosinfo
	attribute :uptime
	attribute :hardwaremodel
	attribute :services, Type::Hash
	attribute :sensors, Type::Hash
	attribute :filesystems, Type::Hash
	attribute :pnics, Type::Array
	attribute :vnics
	attribute :route_info
	attribute :vcenter
	collection :vms, :Vm
	list :vdatastores, :Vdatastore
	list :vnetworks, :Vnetwork
	reference :cluster, :Cluster
	reference :vdatacenter, :Vdatacenter
	unique :name
	index :name
end

# Virtual Network(vswitch) object_bucket
class Vnetwork < Ohm::Model
	attribute :name
	attribute :uuid # for dvs
	attribute :portgroups
	attribute :vcenter
	collection :vms, :Vm
	list :hosts, :Host
	reference :vdatacenter, :Vdatacenter
	unique :uuid
	index :name
	index :portgroup
	index :uuid

	def portgroup
		portgroups.to_s.gsub(/"|\[|\]/, '').split(/\s*,\s*/)
	end

end

# Data Store object_bucket
class Vdatastore < Ohm::Model
	attribute :name
	attribute :capacity
	attribute :free
	attribute :used
	attribute :pct_used
	attribute :url
	attribute :accessible
	attribute :vcenter
	list :vms, :Vm
	list :hosts, :Host
	reference :vdatacenter, :Vdatacenter
	unique :url
	index :name
end

# Virtual Machine object_bucket
class Vm < Ohm::Model
	attribute :name
	attribute :overallstatus
	attribute :os
	attribute :guestdisk
	attribute :numcpu
	attribute :memoryallocated
	attribute :hostmemoryusage
	attribute :guestmemoryusage
	attribute :balloonedmemory
	attribute :ipaddr
	attribute :locationid
	attribute :vmwaretools_version
	attribute :vmwaretools_status
	attribute :template
	attribute :usedstorage
	attribute :provisionedstorage
	attribute :consolidationneeded
	attribute :unsharedstorage
	attribute :boottime
	attribute :cleanpoweroff
	attribute :powerstate
	attribute :uptime
	attribute :vcenter
	list :vdatastores, :Vdatastore
	reference :host, :Host
	reference :cluster, :Cluster
	reference :vnetwork, :Vnetwork
	reference :vdatacenter, :Vdatacenter
	unique :locationid
	index :name
	index :locationid
end