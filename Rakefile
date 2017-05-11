#!/usr/bin/env ruby
$:.push File.expand_path(File.dirname(__FILE__) + '/../lib')

APP_ROOT = File.expand_path(File.dirname(__FILE__))

### Task: rdoc
require 'rake'
require 'rake/testtask'
require 'rdoc/task'
require 'gokdok'

Rake::RDocTask.new do |rdoc|
  rdoc.title    = "vgopher v0.1"
  rdoc.rdoc_dir = "#{APP_ROOT}/doc"
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
      rdoc.rdoc_files.include 'LICENSE'      
      rdoc.rdoc_files.include 'bin/api.rb'
      rdoc.rdoc_files.include 'bin/vgopher.rb'
      rdoc.rdoc_files.include 'lib/data_collect.rb'
      rdoc.rdoc_files.include 'lib/opt_config.rb'
      rdoc.rdoc_files.include 'lib/util.rb'
      rdoc.rdoc_files.include 'lib/vc_collect.rb'

end


Gokdok::Dokker.new do |gd|
  gd.remote_path = '' # Put into the root directory
  gd.repo_url = 'git@github.com:syncopatedtech/vgopher.git'
  gd.doc_home = '#{APP_ROOT}/doc'
end
