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
      expect(Ayl::Message).to receive(:from_hash).with('the body').and_return(msg)

      expect(@job.ayl_message).to eq(msg)
    end

    it "should return the same message constructed from the body of the job on subsequent calls" do
      @job.stub(:ybody).and_return('the body')
      msg = Ayl::Message.new(nil,nil,nil)
      expect(Ayl::Message).to receive(:from_hash).with('the body').and_return(msg)

      expect(@job.ayl_message).to eq(msg)

      expect(@job.ayl_message).to eq(msg)
    end

    it "should return nil and send an email if the message body was bad" do
      @job.stub(:ybody).and_return('the body')
      msg = Ayl::Message.new(nil,nil,nil)
      ex = Ayl::UnrecoverableMessageException.new
      expect(Ayl::Message).to receive(:from_hash).with('the body').and_raise(ex)

      mock_mailer = double("Mailer")
      expect(mock_mailer).to receive(:deliver_message).with(anything(), ex)

      expect(Ayl::Mailer).to receive(:instance).and_return(mock_mailer)

      expect(@job.ayl_message).to be_nil
    end

  end

  context '#ayl_delete' do

    it "should call the delete method on the job" do
      expect(@job).to receive(:delete)

      @job.ayl_delete
    end

    it "should send an email if the delete method raises an exception" do
      ex = Exception.new
      expect(@job).to receive(:delete).and_raise(ex)

      mock_mailer = double("Mailer")
      expect(mock_mailer).to receive(:deliver_message).with(anything(), ex)

      expect(Ayl::Mailer).to receive(:instance).and_return(mock_mailer) 

      @job.ayl_delete
    end

  end

  context '#ayl_decay' do

    it "should call the decay with no arguments when nil delay is specified" do
      expect(@job).to receive(:decay).with()

      @job.ayl_decay(nil)
    end

    it "should call the decay with no arguments when no delay is specified" do
      expect(@job).to receive(:decay).with()

      @job.ayl_decay
    end

    it "should call the decay with no arguments when no delay is specified" do
      expect(@job).to receive(:decay).with(10)

      @job.ayl_decay(10)
    end

    it "should send an email if the decay method raises an exception" do
      ex = Exception.new
      expect(@job).to receive(:decay).and_raise(ex)

      mock_mailer = double("Mailer")
      expect(mock_mailer).to receive(:deliver_message).with(anything(), ex)

      expect(Ayl::Mailer).to receive(:instance).and_return(mock_mailer)

      @job.ayl_decay
    end

  end

  context '#ayl_bury' do

    it "should call the bury method on the job" do
      expect(@job).to receive(:bury)

      @job.ayl_bury
    end

    it "should send an email if the bury method raises an exception" do
      ex = Exception.new
      expect(@job).to receive(:bury).and_raise(ex)

      mock_mailer = double("Mailer")
      expect(mock_mailer).to receive(:deliver_message).with(anything(), ex)

      expect(Ayl::Mailer).to receive(:instance).and_return(mock_mailer)

      @job.ayl_bury
    end

  end

  context '#handle_decay' do

    it "should decay the job if the number of times the job has been reserved is less than the configured failed job count" do
      mock_options = double("options")
      expect(mock_options).to receive(:failed_job_count).and_return(2)
      expect(mock_options).to receive(:failed_job_delay).and_return(3)

      mock_message = double("message")
      expect(mock_message).to receive(:options).exactly(2).times.and_return(mock_options)

      expect(@job).to receive(:reserves).and_return(1)
      expect(@job).to receive(:ayl_message).exactly(2).times.and_return(mock_message)
      expect(@job).to receive(:ayl_decay).with(3)

      @job.handle_decay(Exception.new)
    end

    it "should bury the job if the number of times the job has been reserved is the same or more than the configured failed job count" do
      mock_options = double("options")
      expect(mock_options).to receive(:failed_job_count).and_return(2)

      mock_message = double("message")
      expect(mock_message).to receive(:options).and_return(mock_options)
      expect(mock_message).to receive(:code).and_return('the code')

      expect(@job).to receive(:reserves).and_return(2)
      expect(@job).to receive(:ayl_message).exactly(2).times.and_return(mock_message)
      expect(@job).to receive(:ayl_bury)

      mock_mailer = double('Ayl::Mailer')
      expect(mock_mailer).to receive(:burying_job).with('the code')

      expect(Ayl::Mailer).to receive(:instance).and_return(mock_mailer)

      @job.handle_decay(Exception.new)
    end

  end

end
