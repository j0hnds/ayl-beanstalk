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
        while true
          break if @stop
          job = pool.reserve
          break if job.nil?
          msg = nil
          begin
            msg = Ayl::Message.from_hash(job.ybody)
            process_message(msg)
            delete_job(job)
          rescue Ayl::UnrecoverableMessageException => ex
            logger.error "#{self.class.name} Unrecoverable exception in process_messages: #{ex}"
            Ayl::Mailer.instance.deliver_message("#{self.class.name} Unrecoverable exception in process_messages", ex)
            delete_job(job)
          rescue SystemExit
            # This exception is raised when 'Kernel.exit' is called. In this case
            # we want to make sure the job is deleted, then we simply re-raise
            # the exception and we go bye-bye.
            delete_job(job)
            raise
          rescue Exception => ex
            logger.error "#{self.class.name} Exception in process_messages: #{ex}\n#{ex.backtrace.join("\n")}"
            if msg.options.decay_failed_job
              handle_job_decay(job, ex)
            else
              Ayl::Mailer.instance.deliver_message("#{self.class.name} Exception in process_messages.", ex)
            end
          end
        end
      end

      def handle_job_decay(job, ex)
        logger.debug "Age of job: #{job.age}"
        if job.age > 60
          Ayl::Mailer.instance.deliver_message("#{self.class.name} Deleting decayed job; it just took too long.", ex)
          logger.debug "Deleting job"
          delete_job(job)
        else
          logger.debug "Decaying job"
          decay_job(job)
        end
      end

      def delete_job(job)
        job.delete
      rescue RuntimeError => ex
        logger.error "#{self.class.name} Error deleting job: #{ex}\n#{ex.backtrace.join("\n")}"
        Ayl::Mailer.instance.deliver_message("#{self.class.name} Error deleting job", ex)
      end

      def decay_job(job)
        job.decay
      rescue RuntimeError => ex
        logger.error "#{self.class.name} Error decaying job: #{ex}\n#{ex.backtrace.join("\n")}"
        Ayl::Mailer.instance.deliver_message("#{self.class.name} Error decaying job", ex)
      end

    end

  end

end
