module Ayl

  module Beanstalk

    class Engine
      include Ayl::Logging
      include Ayl::Beanstalk::Pool

      attr_reader :host, :port

      def initialize(host='localhost', port=11300)
        logger.debug "#{self.class.name}.initialize(#{host.inspect}, #{port})"
        @host = host
        @port = port
      end

      def asynchronous?() true end

      def is_connected?
        connected = true
        begin
          pool
        rescue ::Beaneater::NotConnected => ex
          logger.error "#{self.class.name} not connected error: #{ex}"
          connected = false
        end
        connected
      end

      def submit(message)
        log_call(:submit) do
          begin
            tube = pool.tubes[message.options.queue_name]
            code = message.to_rrepr
            logger.info "#{self.class.name} submitting '#{code}' to tube '#{message.options.queue_name}'"
            tube.put(message.to_hash.to_json, 
                     pri: message.options.priority, 
                     delay: message.options.delay, 
                     ttr: message.options.time_to_run)
          rescue Exception => ex
            logger.error "Error submitting message to beanstalk: #{ex}"
            Ayl::Mailer.instance.deliver_message("Error submitting message to beanstalk", ex)
          end
        end
      end

      def worker
        Ayl::Beanstalk::Worker.new(@host, @port)
      end

    end

    
  end

end
