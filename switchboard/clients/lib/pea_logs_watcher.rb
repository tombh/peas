# Start an indefinitely running thread to capture all the logs from a single docker container. Logs
# are sent to the DB via the Peas Switchboard
class PeaLogsWatcher
  include Celluloid::IO
  include Celluloid::Logger

  READ_TIMEOUT = 52*7*24*60*60 # One year

  def initialize pea
    info "Starting to watch #{pea.full_name}'s logs for archiving"
    socket = Peas::Switchboard.connection
    socket.puts "app_logs.#{pea._id}"

    # Just make sure the pea's container has booted up first
    if !pea.running?
      Timeout.timeout 60 do
        info "Waiting for #{pea.full_name} to be up and running..."
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
      {:read_timeout => READ_TIMEOUT}
    )
    docker = Docker::Container.get pea.docker_id, {}, conn_no_timeout
    docker.attach(
      stream: true,
      logs: true,
      stdout: true,
      stderr: true,
    ) do |stream, chunk|
      chunk.lines.each do |line|
        line = line.strip!
        socket.puts line if !line.empty?
      end
    end

  rescue Timeout::Error
    error "Log archiver failed to connect to container for (#{pea.full_name}) to collect its logs"
  ensure
    socket.close if socket
    yield if block_given?
  end
end
