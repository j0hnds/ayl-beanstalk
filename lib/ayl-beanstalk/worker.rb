module Ayl

  module Beanstalk

    class Worker < Ayl::Worker
      include Ayl::Logging
      include Ayl::Beanstalk::Pool

      def initialize(host='localhost', port=11300)
        logger.debug "#{self.class.name}.initialize(#{host.inspect}, #{port})"
        @host = host
        @port = port
      end

      def process_messages
        logger.debug "#{self.class.name} entering process_messages loop watching: #{Ayl::MessageOptions.default_queue_name}"

        # Set the queue that we will be watching
        pool.watch(Ayl::MessageOptions.default_queue_name)

        reserve_job do | job |
          begin

            process_message(job.ayl_message) unless job.ayl_message.nil?
            job.ayl_delete

          rescue SystemExit

            # This exception is raised when 'Kernel.exit' is called. In this case
            # we want to make sure the job is deleted, then we simply re-raise
            # the exception and we go bye-bye.
            job.ayl_delete
            raise

          rescue Ayl::Beanstalk::RequiresJobDecay => ex

            # The code in the message body has requested that we throw this job back
            # in the queue with a delay.
            job.ayl_decay(ex.delay)

          rescue Ayl::Beanstalk::RequiresJobBury => ex
            
            # The code in the message body has requested that we throw this job
            # into the 'buried' state. This will allow a human to look the job
            # over and determine if it can be processed
            job.ayl_bury

          rescue Exception => ex

            deal_with_unexpected_exception(job, ex)

          end

        end # reserve_job...

      end

      private

      #
      # The main loop that gets job from the beanstalk queue to process. When a job is
      # received it will be passed to the block for this method.
      #
      def reserve_job
        while true
          job = nil

          begin

            # Sit around and wait for a job to become available
            job = pool.reserve

          rescue Exception => ex

            logger.error "Unexpected exception in reserve_job: #{ex}\n#{ex.backtrace.join("\n")}"
            Ayl::Mailer.instance.deliver_message("Unexpected exception in process_messages.", ex)
            job.ayl_delete unless job.nil?

            # Notice that we are just breaking out of the loop here. Why?
            # Think about the kinds of exceptions that occur here. They will be
            # things like Beanstalk::OUT_OF_MEMORY errors, beanstalkd connection
            # errors, etc. At this point, the worker is finished, kaput. Might as
            # well report and die. That's exactly what will happen.
            break
            
          end

          break if job.nil?

          yield job

        end
      end

      #
      # Deals with the decision to decay or delete job when an unexpected
      # exception is encountered.
      #
      def deal_with_unexpected_exception(job, ex)
        logger.error "Unexpected exception in process_messages: #{ex}\n#{ex.backtrace.join("\n")}"
        if job.ayl_message.options.decay_failed_job
          job.handle_decay(ex)
        else
          job.ayl_delete
          Ayl::Mailer.instance.deliver_message("Exception in process_messages.", ex)
        end
      end

    end

  end

end
