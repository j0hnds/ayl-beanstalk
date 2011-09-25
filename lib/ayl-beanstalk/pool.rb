module Ayl

  module Beanstalk

    module Pool

      def pool
        @pool ||= ::Beanstalk::Pool.new([ "#{@host}:#{@port}" ])
      end

    end

  end

end
