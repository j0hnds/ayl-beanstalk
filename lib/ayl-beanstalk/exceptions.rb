module Ayl

  module Beanstalk

    #
    # Raise this exception to have ayl release the current job and place it in
    # the delay slot for the tube.
    #
    class RequiresJobDecay < StandardError

      attr_reader :delay

      def initialize(delay=nil)
        @delay = delay
      end
    end

    #
    # Raise this exception to have ayl release the current job and place it in
    # the buried slot for the tube.
    #
    class RequiresJobBury < StandardError

    end

  end

end
