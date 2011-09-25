#!/usr/bin/env ruby
#
# Use this script to look at the current beanstalk information. For help
# running this script, enter 'beastalk_info.rb --help' on the command line.
#
require 'date'
require 'optparse'
require 'beanstalk-client'

SLEEP_COMMAND = {
  :type => :rails,
  :code => 'Kernel.sleep(20)' # This message will cause the worker to sleep for 20 seconds
}

#
# This class provides the commands for the script. Each public instance method
# on the class is exposed as a command by the script. So, for example, if the
# user specifies 'beanstalk_info.rb statistics' on the command-line, the script
# will invoke the BeanstalkCommander#statistics method.
#
# When the user asks the script for help ('beanstalk_info.rb --help'), the help
# implementation will ask for the public instance methods for the BeanstalkCommander
# class so that we can present the user with the valid commands
#
class BeanstalkCommander

  def initialize(host, port, tube)
    @host = host
    @port = port
    @tube = tube
  end

  #
  # Lists the statistics for the specified job number
  #
  def job_statistics(job_number)
    raise "Must specify a job number to get the statistics for" unless job_number
    format_statistics(pool.open_connections.first.job_stats(job_number))
  end

  #
  # Lists the statistics for the current tube on beanstalk
  #
  def tube_statistics(*args)
    puts "Statistics for Tube: #{@tube}"
    format_statistics(pool.stats_tube(@tube))
  end

  #
  # Lists the overall statistics for beanstalk
  #
  def statistics(*args)
    puts "Overall Statistics"
    puts "------------------"
    format_statistics(pool.stats)
  end

  #
  # Lists the tubes active on beanstalk
  #
  def list_tubes(*args)
    tubes = pool.list_tubes
    puts "Tubes in use"
    puts "------------"
    tubes.each_pair do | host, tubes |
      puts host
      tubes.each { | tube | puts " - #{tube}" }
    end
  end

  #
  # Displays the job information for the specified job id without
  # reserving the job or removing it from the queue.
  #
  def peek_job(job_number)
    raise "Must specify a job number to peek" unless job_number
    job = pool.peek_job(job_number)
    format_job(job)
  end

  #
  # Deletes the job with the specified job id.
  #
  def delete(job_number)
    raise "Must specify a job number to delete" unless job_number
    pool.open_connections.first.delete(job_number)
  end

  #
  # Displays the most current job on the ready queue
  #
  def peek_ready(*args)
    pool.use(@tube)
    job = pool.peek_ready
    format_job(job)
  end

  #
  # Kick any buried/delayed jobs in te queue
  #
  def kick(*args)
    pool.use(@tube)
    pool.open_connections.first.kick 1
  end

  #
  # Displays the most current job on the delayed queue
  #
  def peek_delayed(*args)
    pool.use(@tube)
    job = pool.peek_delayed
    format_job(job)
  end

  #
  # Displays the most current job on the buried queue
  #
  def peek_buried(*args)
    pool.use(@tube)
    job = pool.peek_buried
    format_job(job)
  end

  #
  # Puts a generic job on the queue (job is specified on the command line)
  #
  def put_job(job_body)
    raise "Must specify a job body to put" unless job_body
    puts "Putting (#{job_body}) on tube: #{@tube}"
    pool.use(@tube)
    pool.put(job_body)
    puts "Job was put"
  end

  def put_ayl_job(job_body)
    raise "Must specify a job body to put" unless job_body
    puts "Putting (#{job_body}) on tube: #{@tube}"
    pool.put({:type => :ayl, :code => job_body}.to_yaml)
    puts "Job was put"
  end

  def put_sleep_job(*args)
    puts "Putting job on tube '#{@tube}' that will sleep for 20 seconds."
    pool.use(@tube)
    pool.put(SLEEP_COMMAND.to_yaml)
  end

  #
  # Reserves the current job on the queue, displays it, and removes it from the
  # queue. The operation is performed against the current queue.
  #
  def eat_job(*args)
    # Reserve the next job on the queue
    pool.watch(@tube)
    job = pool.reserve(10)
    raise "No job to reserve" unless job
    puts "Reserved job"
    format_job(job)
    job.delete
    puts "Deleted job"
  end

  #
  # General purpose tube cleaning mechanism. This allows you to move all the jobs
  # from one tube to another within beanstalk.
  # The tube specified on the command line (-t tube), will be used as the 'from-tube' and
  # the argument to the move_jobs command is the 'to-tube'. When done, you will be a 
  # a time-out error (because the 'reserve' command timed out without finding a job).
  # 
  # It is fast and awesome.
  #
  def move_jobs(to_tube)
    pool.watch(@tube)
    pool.use(to_tube)
    while true
      job = pool.reserve(0) 
      if job
        pool.put(job.body)
        job.delete
      else
        break
      end
    end
  end

  private

  #
  # Returns the connected beanstalk pool
  #
  def pool
    @pool ||= Beanstalk::Pool.new(["#{@host}:#{@port}"])
  end

  #
  # Formats the specified job. Can handle the job returned as a hash and as
  # a job object.
  #
  def format_job(job)
    if job.nil?
      puts "No job..."
    elsif job.is_a?(Hash)
      job.each_pair do | host, job |
        format_job(job)
      end
    else
      puts "Job: #{job.id}: #{job.body}"
    end
  end

  #
  # Standardized statistics formatting for both tube and general statistics.
  #
  def format_statistics(statistics)
    statistics.keys.sort.each do | key |
      puts format("%-25s => %13s", key, statistics[key]) if statistics[key].is_a?(Fixnum)
      puts format("%-25s => %-13s", key, statistics[key]) if statistics[key].is_a?(String)
    end
  end
end

BEANSTALK_HOST_DEFAULT = 'localhost'
BEANSTALK_PORT_DEFAULT = 11300
DEFAULT_APP_TUBE_NAME = "default"

options = {}

# Set up the options supported by the script
optparse = OptionParser.new do | opts |

  # Set a banner, displayed at the top of the help screen
  opts.banner = "Usage: #{$0} [options] command"

  options[:host] = BEANSTALK_HOST_DEFAULT
  opts.on '-h', '--host HOST', "Specify the host running beanstalk. Default (#{BEANSTALK_HOST_DEFAULT})" do | host |
    options[:host] = host
  end

  options[:port] = BEANSTALK_PORT_DEFAULT
  opts.on '-p', '--port PORT', "Specify the beanstalk port number. Default (#{BEANSTALK_PORT_DEFAULT})" do | port |
    options[:port] = port.to_i
  end

  options[:tube] = DEFAULT_APP_TUBE_NAME
  opts.on '-t', '--tube TUBE', "Specify the tube name. Default (#{DEFAULT_APP_TUBE_NAME})" do | tube |
    options[:tube] = tube
  end

  opts.on '-h', '--help', 'Display the help message' do
    puts opts
    puts
    puts "Valid Commands: "
    # The false parameter in the instance_methods call is used to eliminate methods from the
    # super-classes.
    BeanstalkCommander.instance_methods(false).each do | command |
      puts " - #{command}"
    end
    puts
    exit
  end

end

# Parse out the command line
optparse.parse!

begin
  beanstalker = BeanstalkCommander.new(options[:host],
                                       options[:port], 
                                       options[:tube])

  raise "Must specify a command to execute." if ARGV.empty?
  command = ARGV.first
  raise "Invalid command: #{command}" unless beanstalker.respond_to?(command)

  arguments = ARGV[1..-1]
  beanstalker.send(command, *arguments)
rescue Exception => ex
  puts "Error: #{ex.message}"
  exit
end
