require 'celluloid/io'

# Watches for incoming jobs and performs them asynchronously
class WorkerReceiver
  include Celluloid::IO
  include Celluloid::Logger

  def initialize(queue)
    socket = Peas::Switchboard.connection
    socket.puts "subscribe.jobs_for.#{queue}"
    async.listen socket, queue
  end

  def listen(socket, queue)
    while job = socket.gets
      WorkerRunner.new job, queue
    end
  end
end
