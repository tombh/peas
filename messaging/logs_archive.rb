require_relative '../config/boot'
require 'nats/client'

["TERM", "INT", "SIGINT"].each { |sig|
  Signal.trap(sig) {
    exit
    `kill -5 #{Process.pid}`
  }
}

NATS.on_error { |err| puts "Server Error: #{err}"; exit! }

# Stream the ouput of a command and publish to NATS
# TODO: use Docker::Container.logs when it becomes available
def stream_logs pea
  # Just make sure the pea's container has booted up first
  while !pea.running? do
    sleep 1
  end
  IO.popen("docker logs -f #{pea.docker_id} 2>&1") do |data|
    while line = data.gets
      line.strip!
      next if line.empty?
      NATS.start do
        NATS.publish("logs.#{pea.app._id}.#{pea._id}", line){ NATS.stop }
      end
    end
    data.close
    if $?.to_i > 0
      raise "Docker logs exited with non-zero status"
    end
  end
end

# Keep a list of peas that are currently being logged.
# Needs to be externally persisted because Process.fork can't change parent vars
$redis = Redis.new
$redis.set 'watched_peas_logs', '[]'
def get_watched_peas_logs
  JSON.parse $redis.get('watched_peas_logs')
end
def set_watched_peas_logs list
  $redis.set('watched_peas_logs', list.to_json)
end

loop do
  # Fetch the latest list of peas
  Pea.all.each do |pea|
    # If the pea is not being watched then create a child process to collect its logs
    if !pea._id.to_s.in? get_watched_peas_logs
      puts "Starting to watch #{pea.app.name} #{pea.process_type}.#{pea.process_number}"
      Process.fork do
        $redis = Redis.new
        stream_logs pea
        # Once the above command finishes (usually because the container no longer exists) we don't
        # need to collect its logs
        puts "Finished watching #{pea.process_type}.#{pea.process_number}"
        set_watched_peas_logs get_watched_peas_logs.delete_if{|p| p == pea._id.to_s}
      end
      # Add the pea to the watched list
      set_watched_peas_logs get_watched_peas_logs.push(pea._id.to_s)
    end
  end
  sleep 1 # bit of a breather
end
