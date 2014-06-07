require 'celluloid/io'

# Oversees the creation of threads to wacth individual pea containers for log data. One thread is
# created per container. Logs are streamed to a capped collection in the DB via a Swichboard socket.
class LogsArchiver
  include Celluloid::IO
  include Celluloid::Logger

  # Keep track of which peas are currently being wacthed, so we don't watch them twice
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
        async.watch pea
      end
      sleep 1 # No need to hammer the DB
    end
  end

  # Start a separate thread to watch an individual pea's docker container for its log output
  def watch pea
    # Passes in the current Actor so it can updated the @watched list
    PeaLogsWatcher.new(pea, Actor.current) if !pea._id.in? @watched
  rescue
    # Don't want the whole LogArchiver daemon to restart, so be forgiving about all exceptions.
    # Celluloid logs the error anyway.
  end
end
