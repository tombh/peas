require 'celluloid/io'

# Watches for incoming jobs and performs them asynchronously
class WorkerReceiver
  include Celluloid::IO
  include Celluloid::Logger

  def initialize
    controller_queue = Peas::Switchboard.connection
    pod_queue = Peas::Switchboard.connection
    # Subscribe to the jobs queue
    controller_queue.puts "subscribe.jobs_for.controller"
    pod_queue.puts "subscribe.jobs_for.#{Peas.current_docker_host_id}"
    loop do
      # TODO: does this actually loop, or are the gets() blocking?
      async.new_job controller_queue.gets
      async.new_job pod_queue.gets
      sleep 0.01
    end
  end

  def new_job job, socket
    WorkerRunner.new job, socket
  end
end
