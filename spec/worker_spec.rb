require 'spec_helper'
require 'beanstalk-client'
require 'active_record'
require 'active_record/errors'

describe Ayl::Beanstalk::Worker do

  context "Message Processing" do

    before(:each) do
      @worker = Ayl::Beanstalk::Worker.new
      @worker.stub_chain(:logger, :info)
      @worker.stub_chain(:logger, :error)
    end
    
    it "should wait for a message to be received from beanstalk and process it" do
      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:delete)
      mock_job.should_receive(:ybody).and_return({ :type => :ayl, :code => "23.to_s(2)" })

      mock_pool = mock("Beanstalk::Pool")
      mock_pool.should_receive(:watch).with("default")
      # Returns nil on the second call.
      mock_pool.should_receive(:reserve).and_return(mock_job, nil)
      
      mock_message = mock("Ayl::Message")
      mock_message.should_receive(:evaluate)
      Ayl::Message.stub(:from_hash).with({ :type => :ayl, :code => "23.to_s(2)" }).and_return(mock_message)

      ::Beanstalk::Pool.should_receive(:new).with([ "localhost:11300" ]).and_return(mock_pool)

      @worker.process_messages
      
    end

    it "should raise an UnrecoverableMessageException when the message body is not a valid hash" do
      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:delete)
      mock_job.should_receive(:ybody).and_return("a string")
      mock_job.should_not_receive(:age)

      mock_pool = mock("Beanstalk::Pool")
      mock_pool.should_receive(:watch).with("default")
      # Returns nil on the second call.
      mock_pool.should_receive(:reserve).and_return(mock_job, nil)

      Ayl::Message.stub(:from_hash).with("a string").and_raise(Ayl::UnrecoverableMessageException)

      ::Beanstalk::Pool.should_receive(:new).with([ "localhost:11300" ]).and_return(mock_pool)

      @worker.process_messages
    end

    it "should raise an UnrecoverableJobException when the message body is not a valid job type" do
      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:delete)
      mock_job.should_receive(:ybody).and_return({ :type => :junk, :code => "Dog" })
      mock_job.should_not_receive(:age)

      mock_pool = mock("Beanstalk::Pool")
      mock_pool.should_receive(:watch).with("default")
      # Returns nil on the second call.
      mock_pool.should_receive(:reserve).and_return(mock_job, nil)

      Ayl::Message.stub(:from_hash).with({ :type => :junk, :code => "Dog" }).and_raise(Ayl::UnrecoverableMessageException)

      ::Beanstalk::Pool.should_receive(:new).with([ "localhost:11300" ]).and_return(mock_pool)

      @worker.process_messages
    end

    it "should raise an UnrecoverableJobException when there is no code in the message body" do
      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:delete)
      mock_job.should_receive(:ybody).and_return({ :type => :ayl })
      mock_job.should_not_receive(:age)

      mock_pool = mock("Beanstalk::Pool")
      mock_pool.should_receive(:watch).with("default")
      # Returns nil on the second call.
      mock_pool.should_receive(:reserve).and_return(mock_job, nil)

      Ayl::Message.stub(:from_hash).with({ :type => :ayl }).and_raise(Ayl::UnrecoverableMessageException)

      ::Beanstalk::Pool.should_receive(:new).with([ "localhost:11300" ]).and_return(mock_pool)

      @worker.process_messages
    end

    it "should decay a job that receives an active-record exception on receipt of message that is less than 60 seconds old" do
      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:decay)
      mock_job.should_receive(:ybody).and_return({ :type => :ayl, :code => "Dog" })
      mock_job.should_receive(:age).and_return(10)

      mock_pool = mock("Beanstalk::Pool")
      mock_pool.should_receive(:watch).with("default")
      mock_pool.should_receive(:reserve).and_return(mock_job, nil)

      mock_message = mock("Ayl::Message")
      mock_message.should_receive(:evaluate).and_raise(ActiveRecord::RecordNotFound)
      Ayl::Message.stub(:from_hash).with({ :type => :ayl, :code => "Dog" }).and_return(mock_message)

      ::Beanstalk::Pool.should_receive(:new).with([ "localhost:11300" ]).and_return(mock_pool)

      @worker.process_messages
    end

    it "should delete a job that receives an active-record exception on receipt of message that is more than 60 seconds old" do
      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:delete)
      mock_job.should_receive(:ybody).and_return({ :type => :ayl, :code => "Dog" })
      mock_job.should_receive(:age).and_return(65)

      mock_pool = mock("Beanstalk::Pool")
      mock_pool.should_receive(:watch).with("default")
      mock_pool.should_receive(:reserve).and_return(mock_job, nil)

      mock_message = mock("Ayl::Message")
      mock_message.should_receive(:evaluate).and_raise(ActiveRecord::RecordNotFound)
      Ayl::Message.stub(:from_hash).with({ :type => :ayl, :code => "Dog" }).and_return(mock_message)

      ::Beanstalk::Pool.should_receive(:new).with([ "localhost:11300" ]).and_return(mock_pool)

      @worker.process_messages
    end
  end

end
