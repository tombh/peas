# Start an indefinitely running thread to capture all the logs from a single docker container. Logs
# are sent to the DB via the Peas Switchboard
class PeaLogsWatcher
  include Celluloid::IO
  include Celluloid::Logger

  def initialize pea, archiver
    info "Starting to watch #{name(pea)}'s logs for archiving"
    socket = Peas::Switchboard.connection
    socket.puts "app_logs.#{pea._id}"
    archiver.watched << pea._id

    # Just make sure the pea's container has booted up first
    if !pea.running?
      Timeout.timeout 60 do
        info "Waiting for #{name(pea)} to be up and running..."
        while !pea.running? do
          sleep 1
        end
      end
    end

    # Be default Excon (docker-api's socket lib) has a read timeout of 60 seconds. This is a problem
    # if a container doesn't have any activity in a while.
    conn_no_timeout = Docker::Connection.new(
      Peas::DOCKER_SOCKET,
      # Surely there's a better way than just specifying a really long time?
      {:read_timeout => 52*7*24*60*60} # No activity in a year
    )
    docker = Docker::Container.get pea.docker_id, {}, conn_no_timeout
    docker.attach(
      stream: true,
      logs: true,
      stdout: true,
      stderr: true,
    ) do |stream, chunk|
      socket.puts chunk.strip!
    end

  rescue Timeout::Error
    error "Log archiver failed to connect to container for (#{name(pea)}) to collect its logs"
  ensure
    archiver.watched.delete pea._id # Delete this pea from the watch list
    socket.close if socket
    info "Finished watching #{name(pea)}'s logs"
  end

  # Just a nice human-friendly version of the pea we're watching
  def name pea
    "#{pea.name}@#{pea.app.name}"
  end
end
