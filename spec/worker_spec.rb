require 'spec_helper'
require 'beanstalk-client'
require 'active_record'
require 'active_record/errors'

describe Ayl::Beanstalk::Worker do

  context '#reserve_job' do

    before(:each) do
      Kernel.stub(:puts)
      @worker = Ayl::Beanstalk::Worker.new
      @worker.stub_chain(:logger, :info)
      @worker.stub_chain(:logger, :error)
      @worker.stub_chain(:logger, :debug)

      @mock_pool = double("Beanstalk::Pool")
      
      expect(::Beanstalk::Pool).to receive(:new).with([ "localhost:11300" ]).and_return(@mock_pool)
    end

    it "should loop until there are no more jobs from beanstalk" do
      mock_job1 = double("Beanstalk::Job")
      mock_job2 = double("Beanstalk::Job")

      expect(@mock_pool).to receive(:reserve).and_return(mock_job1, mock_job2, nil)

      index = 0

      @worker.send(:reserve_job) do | job |
        expect(job).to eq([ mock_job1, mock_job2 ][index])
        index += 1
      end

      index.should == 2
      
    end

    it "should report any exception while waiting for a job" do
      expect(@mock_pool).to receive(:reserve).and_raise('It blew')

      mock_mailer = double("Mailer")
      expect(mock_mailer).to receive(:deliver_message).with(any_args())

      expect(Ayl::Mailer).to receive(:instance).and_return(mock_mailer)

      @worker.send(:reserve_job) do | job |
      end
    end

  end

  context '#deal_with_unexpected_exception' do

    before(:each) do
      Kernel.stub(:puts)
      @worker = Ayl::Beanstalk::Worker.new
      @worker.stub_chain(:logger, :info)
      @worker.stub_chain(:logger, :error)
      @worker.stub_chain(:logger, :debug)
    end
      
    it "should call the job's handle_decay method if the message requires the job to decay" do
      mock_job = double("Beanstalk::Job")

      mock_options = double("options")
      expect(mock_options).to receive(:failed_job_handler).and_return('decay')

      mock_message = double("message")
      mock_message.should_receive(:options).and_return(mock_options)

      expect(mock_job).to receive(:ayl_message).and_return(mock_message)

      mock_exception = double("Exception")
      expect(mock_exception).to receive(:backtrace).and_return([])
      expect(mock_job).to receive(:handle_decay).with(mock_exception)

      @worker.send(:deal_with_unexpected_exception, mock_job, mock_exception)
    end

    it "should call the job's ayl_delete method if the message requires the job to be deleted" do
      mock_job = double("Beanstalk::Job")

      mock_options = double("options")
      expect(mock_options).to receive(:failed_job_handler).and_return('delete')

      mock_message = double("message")
      expect(mock_message).to receive(:options).and_return(mock_options)

      expect(mock_job).to receive(:ayl_message).and_return(mock_message)

      mock_exception = double("Exception")
      expect(mock_exception).to receive(:backtrace).and_return([])
      expect(mock_job).to receive(:ayl_delete)

      mock_mailer = double("Mailer")
      expect(mock_mailer).to receive(:deliver_message).with(any_args())

      expect(Ayl::Mailer).to receive(:instance).and_return(mock_mailer)

      @worker.send(:deal_with_unexpected_exception, mock_job, mock_exception)
    end

    it "should call the job's ayl_bury method if the message requires the job to be buried" do
      mock_job = double("Beanstalk::Job")

      mock_options = double("options")
      expect(mock_options).to receive(:failed_job_handler).and_return('bury')

      mock_message = double("message")
      expect(mock_message).to receive(:options).and_return(mock_options)

      mock_job.should_receive(:ayl_message).and_return(mock_message)

      mock_exception = double("Exception")
      expect(mock_exception).to receive(:backtrace).and_return([])
      expect(mock_job).to receive(:ayl_bury)

      mock_mailer = double("Mailer")
      expect(mock_mailer).to receive(:deliver_message).with(any_args())

      expect(Ayl::Mailer).to receive(:instance).and_return(mock_mailer)

      @worker.send(:deal_with_unexpected_exception, mock_job, mock_exception)
    end

  end

  context "Message Processing" do

    before(:each) do
      Kernel.stub(:puts)
      @worker = Ayl::Beanstalk::Worker.new
      @worker.stub_chain(:logger, :info)
      @worker.stub_chain(:logger, :error)
      @worker.stub_chain(:logger, :debug)
      Ayl::MessageOptions.default_queue_name = 'the queue name'

      @mock_pool = double("Beanstalk::Pool")
      expect(@mock_pool).to receive(:watch).with('the queue name')
      @worker.stub(:pool).and_return(@mock_pool)
    end

    it "should process a message received from beanstalk" do
      mock_message = double("Ayl::Message")

      mock_job = double("Beanstalk::Job")
      expect(mock_job).to receive(:ayl_message).at_least(1).times.and_return(mock_message)
      expect(mock_job).to receive(:ayl_delete)

      expect(@worker).to receive(:process_message).with(mock_message)

      expect(@worker).to receive(:reserve_job).and_yield(mock_job)

      @worker.process_messages
    end

    it "should do nothing if the received message is invalid (nil)" do
      mock_job = double("Beanstalk::Job")
      expect(mock_job).to receive(:ayl_message).at_least(1).times.and_return(nil)
      expect(mock_job).to receive(:ayl_delete)

      expect(@worker).not_to receive(:process_message)

      expect(@worker).to receive(:reserve_job).and_yield(mock_job)

      @worker.process_messages
    end

    it "should delete the job and re-raise the exception on a SystemExit" do
      mock_message = double("Ayl::Message")

      mock_job = double("Beanstalk::Job")
      expect(mock_job).to receive(:ayl_message).at_least(1).times.and_return(mock_message)
      expect(mock_job).to receive(:ayl_delete)

      expect(@worker).to receive(:process_message).with(mock_message).and_raise(SystemExit)

      expect(@worker).to receive(:reserve_job).and_yield(mock_job)

      expect { @worker.process_messages }.to raise_error(SystemExit)
    end

    it "should decay the job if the message requires it" do
      mock_message = double("Ayl::Message")

      mock_job = double("Beanstalk::Job")
      expect(mock_job).to receive(:ayl_message).at_least(1).times.and_return(mock_message)
      expect(mock_job).to receive(:ayl_decay).with(20)

      expect(@worker).to receive(:process_message).with(mock_message).and_raise(Ayl::Beanstalk::RequiresJobDecay.new(20))

      expect(@worker).to receive(:reserve_job).and_yield(mock_job)

      @worker.process_messages
    end

    it "should bury the job if the message requires it" do
      mock_message = double("Ayl::Message")

      mock_job = double("Beanstalk::Job")
      expect(mock_job).to receive(:ayl_message).at_least(1).times.and_return(mock_message)
      expect(mock_job).to receive(:ayl_bury)

      expect(@worker).to receive(:process_message).with(mock_message).and_raise(Ayl::Beanstalk::RequiresJobBury)

      expect(@worker).to receive(:reserve_job).and_yield(mock_job)

      @worker.process_messages
    end

    it "should handle all other unexpected exceptions" do
      mock_message = double("Ayl::Message")

      mock_job = double("Beanstalk::Job")
      expect(mock_job).to receive(:ayl_message).at_least(1).times.and_return(mock_message)

      ex = Exception.new

      expect(@worker).to receive(:process_message).with(mock_message).and_raise(ex)

      expect(@worker).to receive(:reserve_job).and_yield(mock_job)
      expect(@worker).to receive(:deal_with_unexpected_exception).with(mock_job, ex)

      @worker.process_messages
    end

  end


end
