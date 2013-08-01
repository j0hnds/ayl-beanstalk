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

      @mock_pool = mock("Beanstalk::Pool")
      
      ::Beanstalk::Pool.should_receive(:new).with([ "localhost:11300" ]).and_return(@mock_pool)
    end

    it "should loop until there are no more jobs from beanstalk" do
      mock_job1 = mock("Beanstalk::Job")
      mock_job2 = mock("Beanstalk::Job")

      @mock_pool.should_receive(:reserve).and_return(mock_job1, mock_job2, nil)

      index = 0

      @worker.send(:reserve_job) do | job |
        job.should == [ mock_job1, mock_job2 ][index]
        index += 1
      end

      index.should == 2
      
    end

    it "should report any exception while waiting for a job" do
      @mock_pool.should_receive(:reserve).and_raise('It blew')

      mock_mailer = mock("Mailer")
      mock_mailer.should_receive(:deliver_message).with(any_args())

      Ayl::Mailer.should_receive(:instance).and_return(mock_mailer)

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
      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:ayl_message).and_return do 
        mock("message").tap do | mock_message |
          mock_message.should_receive(:options).and_return do
            mock("options").tap do | mock_options |
              mock_options.should_receive(:decay_failed_job).and_return(true)
            end
          end
        end
      end

      mock_exception = mock("Exception")
      mock_exception.should_receive(:backtrace).and_return([])
      mock_job.should_receive(:handle_decay).with(mock_exception)

      @worker.send(:deal_with_unexpected_exception, mock_job, mock_exception)
    end

    it "should call the job's ayl_delete method if the message requires the job to be deleted" do
      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:ayl_message).and_return do 
        mock("message").tap do | mock_message |
          mock_message.should_receive(:options).and_return do
            mock("options").tap do | mock_options |
              mock_options.should_receive(:decay_failed_job).and_return(false)
            end
          end
        end
      end

      mock_exception = mock("Exception")
      mock_exception.should_receive(:backtrace).and_return([])
      mock_job.should_receive(:ayl_delete)

      mock_mailer = mock("Mailer")
      mock_mailer.should_receive(:deliver_message).with(any_args())

      Ayl::Mailer.should_receive(:instance).and_return(mock_mailer)

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

      @mock_pool = mock("Beanstalk::Pool")
      @mock_pool.should_receive(:watch).with('the queue name')
      @worker.stub(:pool).and_return(@mock_pool)
    end

    it "should process a message received from beanstalk" do
      mock_message = mock("Ayl::Message")

      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:ayl_message).at_least(1).times.and_return(mock_message)
      mock_job.should_receive(:ayl_delete)

      @worker.should_receive(:process_message).with(mock_message)

      @worker.should_receive(:reserve_job).and_yield(mock_job)

      @worker.process_messages
    end

    it "should do nothing if the received message is invalid (nil)" do
      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:ayl_message).at_least(1).times.and_return(nil)
      mock_job.should_receive(:ayl_delete)

      @worker.should_not_receive(:process_message)

      @worker.should_receive(:reserve_job).and_yield(mock_job)

      @worker.process_messages
    end

    it "should delete the job and re-raise the exception on a SystemExit" do
      mock_message = mock("Ayl::Message")

      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:ayl_message).at_least(1).times.and_return(mock_message)
      mock_job.should_receive(:ayl_delete)

      @worker.should_receive(:process_message).with(mock_message).and_raise(SystemExit)

      @worker.should_receive(:reserve_job).and_yield(mock_job)

      lambda { @worker.process_messages }.should raise_error(SystemExit)
    end

    it "should decay the job if the message requires it" do
      mock_message = mock("Ayl::Message")

      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:ayl_message).at_least(1).times.and_return(mock_message)
      mock_job.should_receive(:ayl_decay).with(20)

      @worker.should_receive(:process_message).with(mock_message).and_raise(Ayl::Beanstalk::RequiresJobDecay.new(20))

      @worker.should_receive(:reserve_job).and_yield(mock_job)

      @worker.process_messages
    end

    it "should bury the job if the message requires it" do
      mock_message = mock("Ayl::Message")

      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:ayl_message).at_least(1).times.and_return(mock_message)
      mock_job.should_receive(:ayl_bury)

      @worker.should_receive(:process_message).with(mock_message).and_raise(Ayl::Beanstalk::RequiresJobBury)

      @worker.should_receive(:reserve_job).and_yield(mock_job)

      @worker.process_messages
    end

    it "should handle all other unexpected exceptions" do
      mock_message = mock("Ayl::Message")

      mock_job = mock("Beanstalk::Job")
      mock_job.should_receive(:ayl_message).at_least(1).times.and_return(mock_message)

      ex = Exception.new

      @worker.should_receive(:process_message).with(mock_message).and_raise(ex)

      @worker.should_receive(:reserve_job).and_yield(mock_job)
      @worker.should_receive(:deal_with_unexpected_exception).with(mock_job, ex)

      @worker.process_messages
    end

  end


end
