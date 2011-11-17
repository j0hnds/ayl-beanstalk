require 'spec_helper'
require 'optparse'

describe "ayl_worker script" do

  before(:each) do
    ARGV.clear
    @ayl_script = File.join(File.dirname(File.expand_path(__FILE__)), '../bin/ayl_worker')
  end

  context "handling command line" do

    it "requires that an application path be specified" do
      Object.any_instance.stub(:puts)
      lambda { load(@ayl_script, true) }.should exit_with_code(64)
    end

    it "should exit with a status code of 0 if help is invoked" do
      ARGV << '--help'
      Object.any_instance.stub(:puts)
      lambda { load(@ayl_script, true) }.should exit_with_code(0)
    end

    it "should exit when an invalid argument is specified" do
      ARGV << '--not-real'

      lambda { load(@ayl_script, true) }.should raise_error(OptionParser::InvalidOption)
    end

    it "should set the correct tube name when specified on the command line" do
      ARGV.concat [ "-a", "support", "-t", "the-tube" ]
      
      Ayl::MessageOptions.should_receive(:default_queue_name=).with('the-tube')

      mock_worker = mock("Worker")
      mock_worker.should_receive(:process_messages)
      mock_worker.should_receive(:eval_binding=)

      mock_active_engine = mock("ActiveEngine")
      mock_active_engine.should_receive(:worker).and_return(mock_worker)

      Ayl::Engine.should_receive(:get_active_engine).and_return(mock_active_engine)

      load(@ayl_script, true)
    end

    it "should set the default tube name when not specified on the command line" do
      ARGV.concat [ "-a", "support" ]
      
      Ayl::MessageOptions.should_receive(:default_queue_name=).with('default')

      mock_worker = mock("Worker")
      mock_worker.should_receive(:process_messages)
      mock_worker.should_receive(:eval_binding=)

      mock_active_engine = mock("ActiveEngine")
      mock_active_engine.should_receive(:worker).and_return(mock_worker)

      Ayl::Engine.should_receive(:get_active_engine).and_return(mock_active_engine)

      load(@ayl_script, true)
    end

    it "should default to a rails production environment if not specified" do
      ARGV.concat [ "-a", "support", "-r" ]

      Ayl::MessageOptions.should_receive(:default_queue_name=).with('default')

      mock_worker = mock("Worker")
      mock_worker.should_receive(:process_messages)
      mock_worker.should_receive(:eval_binding=)

      mock_active_engine = mock("ActiveEngine")
      mock_active_engine.should_receive(:worker).and_return(mock_worker)

      Ayl::Engine.should_receive(:get_active_engine).and_return(mock_active_engine)
      ENV.should_receive(:[]=).with('RAILS_ENV', 'production')

      load(@ayl_script, true)
    end

    it "should use the specified rails environment" do
      ARGV.concat [ "-a", "support", "-r", "-e", "development" ]

      Ayl::MessageOptions.should_receive(:default_queue_name=).with('default')

      mock_worker = mock("Worker")
      mock_worker.should_receive(:process_messages)
      mock_worker.should_receive(:eval_binding=)

      mock_active_engine = mock("ActiveEngine")
      mock_active_engine.should_receive(:worker).and_return(mock_worker)

      Ayl::Engine.should_receive(:get_active_engine).and_return(mock_active_engine)
      ENV.should_receive(:[]=).with('RAILS_ENV', 'development')

      load(@ayl_script, true)
    end

  end

end
