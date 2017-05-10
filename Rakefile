#!/usr/bin/env ruby
$:.push File.expand_path(File.dirname(__FILE__) + '/../lib')

### Task: rdoc
require 'rake'
require 'rake/testtask'
require 'rdoc/task'

Rake::RDocTask.new do |rdoc|
  rdoc.title    = "vgopher v0.1"
  rdoc.rdoc_dir = "doc"
    rdoc.options += [
      '-w', '2',
      '-H',
      '-f', 'darkfish', # This bit
      '-m', 'README.rdoc',
      '--visibility', 'nodoc',
    ]
      rdoc.rdoc_files.include 'README.rdoc'
      rdoc.rdoc_files.include 'features.rdoc'
      rdoc.rdoc_files.include 'TODO.rdoc'
      rdoc.rdoc_files.include 'bin/api.rb'
      rdoc.rdoc_files.include 'bin/vgopher.rb'
      rdoc.rdoc_files.include 'lib/data_collect.rb'
      rdoc.rdoc_files.include 'lib/ohm_objects.rb'
      rdoc.rdoc_files.include 'lib/opt_config.rb'
      rdoc.rdoc_files.include 'lib/util.rb'
      rdoc.rdoc_files.include 'lib/vc_collect.rb'

end