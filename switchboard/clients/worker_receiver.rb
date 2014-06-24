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
    loop do
      new_job socket.gets
    end
  end

  def new_job job
    WorkerRunner.new job
  end
end
