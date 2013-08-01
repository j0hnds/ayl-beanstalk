#
# I don't like to call this a monkey-patch. I simply want to extend the
# Beanstalk::Job to take care of some things that are best left to it.
# So let's just call it 'ayl Duck-punching'.
#
# I promise that no methods overridden here; only new methods added.
#
class Beanstalk::Job
  include Ayl::Logging

  #
  # Return the body of the job as an Ayl::Message. If the message is improperly
  # formatted, then nil is returned.
  #
  def ayl_message
    @msg ||= Ayl::Message.from_hash(ybody)
  rescue Ayl::UnrecoverableMessageException => ex
    logger.error "Error extracting message from beanstalk job: #{ex}"
    Ayl::Mailer.instance.deliver_message "Error extracting message from beanstalk job", ex
    @msg = nil
  end

  #
  # Delete the job handling any exceptions that occur during the job deletion
  # (like the job not existing).
  #
  def ayl_delete
    delete
  rescue Exception => ex
    logger.error "Error deleting job: #{ex}\n#{ex.backtrace.join("\n")}"
    Ayl::Mailer.instance.deliver_message("Error deleting job", ex)
  end

  #
  # Decay the job handling any exceptions that occur during the job decay 
  # process.
  #
  def ayl_decay(delay=nil)
    decay(*[ delay ].compact)
  rescue Exception => ex
    logger.error "Error decaying job: #{ex}\n#{ex.backtrace.join("\n")}"
    Ayl::Mailer.instance.deliver_message("Error decaying job", ex)
  end

  # 
  # Bury the job handling any exceptions that occur during the burying
  # process.
  #
  def ayl_bury
    bury
  rescue Exception => ex
    logger.error "Error burying job: #{ex}\n#{ex.backtrace.join("\n")}"
    Ayl::Mailer.instance.deliver_message("Error decaying job", ex)
  end

  #
  # Handle the decay process by deleting the job if its age is more than
  # 60 seconds, but delaying it if it is younger than 60 seconds. Obviously
  # we want to handle any exceptions that occur here.
  #
  def handle_decay(ex)
    logger.debug "Age of job: #{age}"
    if age > 60
      Ayl::Mailer.instance.deliver_message("Deleting decayed job; it just took too long.", ex)
      logger.debug "Deleting job"
      ayl_delete
    else
      logger.debug "Decaying job"
      ayl_decay
    end
  end

end
