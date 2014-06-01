require_relative '../config/boot'
require 'nats/client'

["TERM", "INT", "SIGINT"].each { |sig|
  Signal.trap(sig) {
    exit!
  }
}

NATS.on_error { |err| puts "Server Error: #{err}"; exit! }

def serve
  NATS.start(autostart: true) do
    puts "Server listening..."

    # Insert individual app logs into capped collection
    NATS.subscribe('logs.>') do |msg, _, sub|
      parts = sub.split('.')
      app = App.find(parts[1])
      pea = Pea.find(parts[2])
      line = "#{DateTime.now} app[#{pea.process_type}.#{pea.process_number}]: #{msg}"
      app_logs_collection = Mongoid::Sessions.default["#{app.first_sha}_logs"]
      app_logs_collection.insert({line: line})
    end

    NATS.subscribe('api.>') do |msg, _, sub|
      parts = sub.split('.')
      app = App.find(parts[1])
      puts "Request to stream logs for #{app.name}"
      Process.fork do
        Mongoid::Sessions.default["#{app.first_sha}_logs"].find.tailable.cursor.each do |doc|
          NATS.start{NATS.publish('cli', doc['line']){NATS.stop}}
        end
      end
    end
  end
end

begin
  serve
rescue Exception => ex
  puts "EXCEPTION! #{ex}"
  retry
end
