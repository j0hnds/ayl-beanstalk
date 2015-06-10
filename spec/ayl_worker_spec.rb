require 'spec_helper'
require 'optparse'
require 'ayl-beanstalk/command_line'

describe "ayl_worker script" do

  before(:each) do
    ARGV.clear
    @ayl_script = File.join(File.dirname(File.expand_path(__FILE__)), '../bin/ayl_worker')
  end

  context "handling command line" do

    it "requires that an application path be specified" do
      Object.any_instance.stub(:puts)
      expect { load(@ayl_script, true) }.to exit_with_code(64)
    end

    it "should exit with a status code of 0 if help is invoked" do
      ARGV << '--help'
      Ayl::CommandLine.stub(:puts)
      expect { load(@ayl_script, true) }.to exit_with_code(0)
    end

    it "should exit when an invalid argument is specified" do
      ARGV << '--not-real'

      expect { load(@ayl_script, true) }.to raise_error(OptionParser::InvalidOption)
    end

    it "should set the correct tube name when specified on the command line" do
      ARGV.concat [ "-a", "support", "-t", "the-tube" ]
      
      expect(Ayl::MessageOptions).to receive(:default_queue_name=).with('the-tube')

      mock_worker = double("Worker")
      expect(mock_worker).to receive(:process_messages)
      expect(mock_worker).to receive(:eval_binding=)

      mock_active_engine = double("ActiveEngine")
      expect(mock_active_engine).to receive(:worker).and_return(mock_worker)

      expect(Ayl::Engine).to receive(:get_active_engine).and_return(mock_active_engine)

      load(@ayl_script, true)
    end

    it "should set the default tube name when not specified on the command line" do
      ARGV.concat [ "-a", "support" ]
      
      expect(Ayl::MessageOptions).to receive(:default_queue_name=).with('default')

      mock_worker = double("Worker")
      expect(mock_worker).to receive(:process_messages)
      expect(mock_worker).to receive(:eval_binding=)

      mock_active_engine = double("ActiveEngine")
      expect(mock_active_engine).to receive(:worker).and_return(mock_worker)

      expect(Ayl::Engine).to receive(:get_active_engine).and_return(mock_active_engine)

      load(@ayl_script, true)
    end

    it "should default to a rails production environment if not specified" do
      ARGV.concat [ "-a", "support", "-r" ]

      expect(Ayl::MessageOptions).to receive(:default_queue_name=).with('default')

      mock_worker = double("Worker")
      expect(mock_worker).to receive(:process_messages)
      expect(mock_worker).to receive(:eval_binding=)

      mock_active_engine = double("ActiveEngine")
      expect(mock_active_engine).to receive(:worker).and_return(mock_worker)

      expect(Ayl::Engine).to receive(:get_active_engine).and_return(mock_active_engine)
      expect(ENV).to receive(:[]=).with('RAILS_ENV', 'production')

      load(@ayl_script, true)
    end

    it "should use the specified rails environment" do
      ARGV.concat [ "-a", "support", "-r", "-e", "development" ]

      expect(Ayl::MessageOptions).to receive(:default_queue_name=).with('default')

      mock_worker = double("Worker")
      expect(mock_worker).to receive(:process_messages)
      expect(mock_worker).to receive(:eval_binding=)

      mock_active_engine = double("ActiveEngine")
      expect(mock_active_engine).to receive(:worker).and_return(mock_worker)

      expect(Ayl::Engine).to receive(:get_active_engine).and_return(mock_active_engine)
      expect(ENV).to receive(:[]=).with('RAILS_ENV', 'development')

      load(@ayl_script, true)
    end

  end

end
