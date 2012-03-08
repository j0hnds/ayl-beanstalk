require 'spec_helper'
require 'ayl-beanstalk/command_line'

describe Ayl::CommandLine do

  context "when extracting the appropriate arguments from the command line" do

    it "grab only the arguments following the application marker" do
      raw_argv = %w{ start -- -a path-to-app -r -e development }
      
      app_arguments = %w{ -a path-to-app -r -e development }

      Ayl::CommandLine.grab_app_arguments(raw_argv).should == app_arguments
    end

    it "raise an exception if no application marker exists in the command line arguments" do
      raw_argv = %w{ start -a path-to-app -r -e development }
      lambda { Ayl::CommandLine.grab_app_arguments(raw_argv) }.should raise_exception
    end

  end

  context "when parsing the command line" do

    it "should extract the correct options from the command line when the short options are used" do
      argv = %w{ -t tube_name -e development -a app_path -r -c config/environment -p pid_path -n the_name }
      parsed_options = Ayl::CommandLine.parse!(argv)
      parsed_options.should == { :tube => 'tube_name', :env => 'development', :app_path => 'app_path', :rails_app => true, :app_require => 'config/environment', :pid_path => 'pid_path', :app_name => 'the_name' }
    end

    it "should extract the correct options from the command line when the long options are used" do
      argv = %w{ --tube tube_name --environment development --app-path app_path --rails --require config/environment --pid-path pid_path --name the_name }
      parsed_options = Ayl::CommandLine.parse!(argv)
      parsed_options.should == { :tube => 'tube_name', :env => 'development', :app_path => 'app_path', :rails_app => true, :app_require => 'config/environment', :pid_path => 'pid_path', :app_name => 'the_name' }
    end

    it "should raise an exception if invalid arguments are provided" do
      argv = %w{ --tuber tube_name --environmen development --apppath app_path --rail --require config/environment --pidpath pid_path }
      lambda { Ayl::CommandLine.parse!(argv) }.should raise_exception
    end

  end

end
