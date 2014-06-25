require 'celluloid/io'

# Watches for incoming jobs and performs them asynchronously
class WorkerReceiver
  include Celluloid::IO
  include Celluloid::Logger

  def initialize
    open_listener 'controller' if Peas.is_controller?
    open_listener Peas.current_docker_host_id if Peas.is_pod?
  end

  def open_listener queue
    socket = Peas::Switchboard.connection
    socket.puts "subscribe.jobs_for.#{queue}"
    async.listen socket
  end

  def listen socket
    sleep 0.1 # To allow the other listener a chance to start listening
    while job = socket.gets do
      new_job job
    end
  end

  def new_job job
    WorkerRunner.new job
  end
end
