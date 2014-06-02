require_relative '../config/boot'
require 'nats/client'

["TERM", "INT", "SIGINT"].each { |sig|
  Signal.trap(sig) {
    exit
    `kill -5 #{Process.pid}`
  }
}

NATS.on_error { |err| puts "Server Error: #{err}"; exit! }

connection = rand(9999999999999999)

NATS.start do
  NATS.subscribe("#{connection}.ping") { |msg, reply| NATS.publish(reply, "HERE!") }
  NATS.subscribe("#{connection}.output"){ |msg, _, sub|
    puts msg
  }
  NATS.publish("api.#{App.first._id}.#{connection}")
end
