require 'celluloid/io'

# Oversees the creation of threads to wacth individual pea containers for log data. One thread is
# created per container. Logs are streamed to a capped collection in the DB via a Swichboard socket.
class LogsArchiver
  include Celluloid::IO
  include Celluloid::Logger

  attr_accessor :watched

  def initialize
    @watched = []
    async.run
  end

  def run
    loop do
      # Fetch the latest list of peas
      Pea.all.each do |pea|
        # If the pea is not being watched then start a new thread to watch it and stream to the DB
        watch pea if !pea._id.in? @watched
      end
       # No need to hammer the DB
      if ENV['RACK_ENV'] != 'test'
        sleep 1
      else
        sleep 0.01
      end
    end
  end

  # Start a separate thread to watch an individual pea's docker container for its log output
  def watch pea
    @watched << pea._id
    PeaLogsWatcher.new(pea) do
      @watched.delete pea._id # Delete this pea from the watch list
      info "Finished watching #{pea.full_name}'s logs"
    end
  rescue
    # Don't want the whole LogArchiver daemon to restart, so be forgiving about all exceptions.
    # Celluloid logs the error anyway.
  end
end
