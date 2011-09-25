module Ayl

  module Beanstalk

    class Worker < Ayl::Worker
      include Ayl::Logging
      include Ayl::Beanstalk::Pool

      def initialize(host='localhost', port=11300)
        logger.info "#{self.class.name}.initialize(#{host.inspect}, #{port})"
        @host = host
        @port = port
      end

      def process_messages
        logger.info "#{self.class.name} entering process_messages loop"
        # trap('TERM') { puts "## Got the term signal"; @stop = true }
        # trap('INT') { puts "## Got the int signal"; @stop = true }
        # Set the queue that we will be watching
        pool.watch(Ayl::MessageOptions.default_queue_name)
        while true
          break if @stop
          job = pool.reserve
          break if job.nil?
          begin
            process_message(Ayl::Message.from_hash(job.ybody))
            job.delete
          rescue Ayl::UnrecoverableMessageException => ex
            logger.error "#{self.class.name} Unrecoverable exception in process_messages: #{ex}"
            job.delete
          rescue Exception => ex
            logger.error "#{self.class.name} Exception in process_messages: #{ex}\n#{ex.backtrace.join("\n")}"
            if job.age > 60
              job.delete
            else
              job.decay
            end
          end
        end
      end

    end

  end

end
