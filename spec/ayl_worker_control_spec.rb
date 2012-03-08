require 'spec_helper'
require 'daemons'
require 'ayl-beanstalk/command_line'

describe 'ayl_worker_control script' do

  before(:each) do
    ARGV.clear
    @ayl_control_script = File.expand_path('../bin/ayl_worker_control', File.dirname(__FILE__))
  end

  context 'handling command line' do

    it "should honor the use of the -a option to name the daemon" do
      ARGV.concat [ '--', '--pid-path', '/tmp', '--name', 'the_name' ]
      Daemons.should_receive(:run).with(anything, { :log_dir => '/tmp', :log_output => true, :dir_mode => :normal, :dir => '/tmp', :app_name => 'the_name' })

      load(@ayl_control_script, true)
    end

    it "should assume the use of the script for the daemon name if no name argument is specified" do
      ARGV.concat [ '--', '--pid-path', '/tmp' ]
      Daemons.should_receive(:run).with(anything, { :log_dir => '/tmp', :log_output => true, :dir_mode => :normal, :dir => '/tmp' })

      load(@ayl_control_script, true)
    end

  end

end
