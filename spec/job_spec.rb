require 'spec_helper'
require 'beanstalk-client'

describe Beanstalk::Job do
  
  before(:each) do
    @job = Beanstalk::Job.new(nil,nil,nil)
    @job.stub_chain(:logger, :error)
    @job.stub_chain(:logger, :debug)
  end

  context '#ayl_message' do

    it "should return the message constructed from the body of the job" do
      @job.stub(:ybody).and_return('the body')
      msg = Ayl::Message.new(nil,nil,nil)
      Ayl::Message.should_receive(:from_hash).with('the body').and_return(msg)

      @job.ayl_message.should == msg
    end

    it "should return the same message constructed from the body of the job on subsequent calls" do
      @job.stub(:ybody).and_return('the body')
      msg = Ayl::Message.new(nil,nil,nil)
      Ayl::Message.should_receive(:from_hash).with('the body').and_return(msg)

      @job.ayl_message.should == msg

      @job.ayl_message.should == msg
    end

    it "should return nil and send an email if the message body was bad" do
      @job.stub(:ybody).and_return('the body')
      msg = Ayl::Message.new(nil,nil,nil)
      ex = Ayl::UnrecoverableMessageException.new
      Ayl::Message.should_receive(:from_hash).with('the body').and_raise(ex)

      Ayl::Mailer.should_receive(:instance).and_return do 
        mock("Mailer").tap do | mock_mailer |
          mock_mailer.should_receive(:deliver_message).with(anything(), ex)
        end
      end

      @job.ayl_message.should == nil
    end

  end

  context '#ayl_delete' do

    it "should call the delete method on the job" do
      @job.should_receive(:delete)

      @job.ayl_delete
    end

    it "should send an email if the delete method raises an exception" do
      ex = Exception.new
      @job.should_receive(:delete).and_raise(ex)

      Ayl::Mailer.should_receive(:instance).and_return do 
        mock("Mailer").tap do | mock_mailer |
          mock_mailer.should_receive(:deliver_message).with(anything(), ex)
        end
      end

      @job.ayl_delete
    end

  end

  context '#ayl_decay' do

    it "should call the decay with no arguments when nil delay is specified" do
      @job.should_receive(:decay).with()

      @job.ayl_decay(nil)
    end

    it "should call the decay with no arguments when no delay is specified" do
      @job.should_receive(:decay).with()

      @job.ayl_decay
    end

    it "should call the decay with no arguments when no delay is specified" do
      @job.should_receive(:decay).with(10)

      @job.ayl_decay(10)
    end

    it "should send an email if the decay method raises an exception" do
      ex = Exception.new
      @job.should_receive(:decay).and_raise(ex)

      Ayl::Mailer.should_receive(:instance).and_return do 
        mock("Mailer").tap do | mock_mailer |
          mock_mailer.should_receive(:deliver_message).with(anything(), ex)
        end
      end

      @job.ayl_decay
    end

  end

  context '#ayl_bury' do

    it "should call the bury method on the job" do
      @job.should_receive(:bury)

      @job.ayl_bury
    end

    it "should send an email if the bury method raises an exception" do
      ex = Exception.new
      @job.should_receive(:bury).and_raise(ex)

      Ayl::Mailer.should_receive(:instance).and_return do 
        mock("Mailer").tap do | mock_mailer |
          mock_mailer.should_receive(:deliver_message).with(anything(), ex)
        end
      end

      @job.ayl_bury
    end

  end

  context '#handle_decay' do

    it "should decay the job if the age of the job is less than 60 seconds" do
      @job.should_receive(:age).at_least(1).times.and_return(2)
      @job.should_receive(:ayl_decay)
      
      ex = Exception.new

      @job.handle_decay(ex)
    end

    it "should decay the job if the age of the job is exactly 60 seconds" do
      @job.should_receive(:age).at_least(1).times.and_return(60)
      @job.should_receive(:ayl_decay)
      
      ex = Exception.new

      @job.handle_decay(ex)
    end

    it "should delete the job and send an email if the job was older than 60 seconds" do
      @job.should_receive(:age).at_least(1).times.and_return(61)
      @job.should_receive(:ayl_delete)
      
      ex = Exception.new

      Ayl::Mailer.should_receive(:instance).and_return do 
        mock("Mailer").tap do | mock_mailer |
          mock_mailer.should_receive(:deliver_message).with(anything(), ex)
        end
      end

      @job.handle_decay(ex)
    end

  end

end
