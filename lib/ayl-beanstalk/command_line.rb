require 'optparse'

module Ayl

  module CommandLine

    BEANSTALK_TUBE_DEFAULT = 'default'
    APP_REQUIRE_DEFAULT = 'config/environment'
    RAILS_ENVIRONMENT_DEFAULT = 'production'

    MARKER = '--'

    def self.grab_app_arguments(argv=ARGV)
      marker_index = argv.index(MARKER)
      raise "No argument marker found!" if marker_index.nil?
      argv[marker_index + 1..-1]
    end

    def self.parse!(argv=ARGV)
      {}.tap do | options |

        optparse = OptionParser.new do | opts |
          
          # Set a banner, displayed at the top of the help screen.
          opts.banner = "Usage: #{$0} [options]"

          options[:tube] = BEANSTALK_TUBE_DEFAULT
          opts.on '-t', '--tube TUBE', "Specify the beanstalk tube to listen to. Default (#{BEANSTALK_TUBE_DEFAULT})." do |tube|
            options[:tube] = tube
          end

          options[:env] = RAILS_ENVIRONMENT_DEFAULT
          opts.on '-e', '--environment ENVIRONMENT', "Specify the Rails environment to use" do |environment|
            options[:env] = environment
          end

          options[:app_path] = nil
          opts.on '-a', '--app-path APP_PATH', "Specify the path to the rails app" do |app_path|
            options[:app_path] = app_path
          end

          options[:rails_app] = false
          opts.on '-r', '--rails', "Indicate that we are starting a rails application" do 
            options[:rails_app] = true
          end

          options[:app_require] = APP_REQUIRE_DEFAULT
          opts.on '-c', '--require APP_REQUIRE', "The file to require when the worker starts up" do | app_require |
            options[:app_require] = app_require
          end

          opts.on '-p', '--pid-path PID_PATH', "The path to the pid file" do | pid_path |
            options[:pid_path] = pid_path
          end

          opts.on '-n', '--name NAME', 'The name to use for the worker daemon (overrides script name)' do | name |
            options[:app_name] = name
          end

          opts.on '-h', '--help', 'Display the help message' do
            puts opts
            exit(0)
          end
        end

        optparse.parse!(argv)
      end # End of .tap

    end

  end

end
