#!/usr/bin/env ruby
$:.push File.expand_path(File.dirname(__FILE__) + '/../lib')



@@word_buckets = [

'vdatacenter' => { 
	attributes: ['name', 'latestupdate'], 
	indexed: ['name'], 
	collections: ['clusters', 'hosts', 'vnetworks', 'vdatastores', 'vms'],
	references: ['client']
},


'cluster' => {
	attributes: [
		'name',
		'overallstatus',
		'effectivememory',
		'effectivecpu',
		'numeffectivehosts',
		'numhosts',
		'totalcpu',
		'totalmemory',
		'vcenter'
	],
	indexed: ['name'],
	collections: ['hosts', 'vms'],
	references: ['vdatacenter']
},


'host' => {
	attributes: [
		'name',
		'overallstatus',
		'hardwaremodel',
		'domain',
		'overallcpuusage',
		'overallmemoryusage',
		'totalmemory',
		'powerstate',
		'connectionState',
		'maintenancemode',
		'biosinfo',
		'uptime',
		'services',
		'sensors',
		'filesystems',
		'route_info',
		'pnics',
		'vnics',
		'vcenter'
    ],
	indexed: ['name'],
	collections: ['vms'],
	lists: ['vdatastores', 'vnetworks'],
	references: ['vdatacenter']
},



'vnetwork' => {
	attributes: [
		'name',
		'uuid',
		'portgroups',
		'vcenter'
	],
	indexed: ['name', 'uuid', 'portgroup'],
	collections: ['vms'],
	lists: ['hosts'],
	references: ['vdatacenter']
},


'vdatastore' => {
	attributes: [
		'name',
		'capacity',
		'free',
		'used',
		'pct_used',
		'url',
		'vcenter'
	],
	indexed: ['name'],
	collections: ['vms'],
	lists: ['hosts'],
	references: ['vdatacenter']
},


'vm' => {
	attributes: [
		'name',
		'powerstate',
		'os',
		'guestdisk',
		'ipaddr',
		'vmwaretools_version',
		'vmwaretools_status',
		'numcpu',
		'memoryallocated',
		'hostmemoryusage',
		'guestmemoryusage',
		'provisionedstorage',
		'usedstorage',
		'unsharedstorage',
		'uptime',
		'overallstatus',
		'balloonedmemory',
		'locationid',
		'vcenter'
    ],
	indexed: ['name'],
	lists: ['vdatastores'],
	references: ['host', 'cluster', 'vnetwork', 'vdatacenter']
}
]