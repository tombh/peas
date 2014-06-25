require 'celluloid/io'

# Watches for incoming jobs and performs them asynchronously
class WorkerReceiver
  include Celluloid::IO
  include Celluloid::Logger

  def initialize queue
    socket = Peas::Switchboard.connection
    socket.puts "subscribe.jobs_for.#{queue}"
    async.listen socket
  end

  def listen socket
    while job = socket.gets do
      WorkerRunner.new job
    end
  end

end
