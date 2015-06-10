require 'spec_helper'
require 'beanstalk-client'
require 'active_record'
require 'active_record/errors'

describe Ayl::Beanstalk::Engine do

  context "Standard API" do

    before(:each) do
      Kernel.stub(:puts)
      @engine = Ayl::Beanstalk::Engine.new
      @engine.stub_chain(:logger, :info)
      @engine.stub_chain(:logger, :debug)
      @engine.stub_chain(:logger, :error)
    end

    it "should default to localhost and 11300 as the host port for the beanstalkd server" do
      expect(@engine.host).to eq('localhost')
      expect(@engine.port).to eq(11300)
    end

    it "should respond true to the asynchronous? message" do
      expect(@engine.asynchronous?).to be true
    end

    it "should return true if it has a valid connection to beanstalk" do
      mock_pool = double("Beanstalk::Pool")

      expect(::Beanstalk::Pool).to receive(:new).with([ "localhost:11300" ]).and_return(mock_pool)

      expect(@engine.is_connected?).to be true
    end

    it "should return false if it does not have a valid connection to beanstalk" do
      expect(::Beanstalk::Pool).to receive(:new).with([ "localhost:11300" ]).and_raise(::Beanstalk::NotConnected)

      expect(@engine.is_connected?).to be false
    end

    context "Message Submission" do
      
      before(:each) do
        @msg = Ayl::Message.new(23, :to_s, Ayl::MessageOptions.new, 2)
      end

      it "should submit the specified message to beanstalk" do
        mock_pool = double("Beanstalk::Pool")
        expect(mock_pool).to receive(:use).with("default")
        expect(mock_pool).to receive(:yput).with( { :type => :ayl, :failed_job_handler => 'delete', :code => "23.to_s(2)" }, 512, 0, 120)

        expect(::Beanstalk::Pool).to receive(:new).with([ "localhost:11300" ]).and_return(mock_pool)

        @engine.submit(@msg)
      end
    end

  end

end
