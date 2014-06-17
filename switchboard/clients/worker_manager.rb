require 'celluloid/io'

# Watches for incoming jobs and performs them asynchronously
class WorkerManager
  include Celluloid::IO
  include Celluloid::Logger

  def initialize
    @socket = Peas::Switchboard.connection
    @socket.puts "worker_register.#{Peas::Switchboard.current_docker_host_id}"
    loop { async.read @socket.gets }
  end

  def read line
    if line == :do_a_job
      WorkerRunner.new line, @socket
    else
      # Kill job?
    end
  end
end
