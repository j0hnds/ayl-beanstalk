#!/usr/bin/env ruby
require 'daemons'

sdir = File.dirname(File.absolute_path($0))
sname = File.basename($0).gsub('_control', '')
spath = File.join(sdir, sname)

Daemons.run(spath, :log_dir => '/tmp', :log_output => true)
