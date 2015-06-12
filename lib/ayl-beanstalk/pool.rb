module Ayl

  module Beanstalk

    module Pool

      def pool
        @pool ||= ::Beaneater.new("#{@host}:#{@port}")
      end

    end

  end

end
