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
      # Fetch all the running docker containers on the current host
      docker_ids = Docker::Container.all.map { |c| c.id }
      docker_ids.each do |id|
        # If the pea is not being watched then start a new thread to watch it and stream to the DB
        next if id.in? @watched
        begin
          pea = Pea.find_by docker_id: id
        rescue Mongoid::Errors::DocumentNotFound
          warn "Couldn't find a corresponding DB record for Docker container #{id}"
        end
        async.watch pea
      end
      # No need to hammer the Docker API
      if ENV['RACK_ENV'] != 'test'
        sleep 1
      else
        sleep 0.01
      end
    end
  end

  # Start a separate thread to watch an individual pea's docker container for its log output
  def watch(pea)
    @watched << pea.docker_id
    PeaLogsWatcher.new(pea) do
      @watched.delete pea.docker_id # Delete this pea from the watch list
      info "Finished watching #{pea.full_name}'s logs"
    end
  rescue
    # Don't want the whole LogArchiver daemon to restart, so be forgiving about all exceptions.
    # Celluloid logs the error anyway.
  end
end
