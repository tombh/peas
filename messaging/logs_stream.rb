require_relative '../config/boot'
require 'nats/client'

["TERM", "INT", "SIGINT"].each { |sig|
  Signal.trap(sig) {
    exit
    `kill -5 #{Process.pid}`
  }
}

NATS.on_error { |err| puts "Server Error: #{err}"; exit! }

NATS.start do
  NATS.subscribe('cli'){ |msg, reply, sub|
    puts msg
  }
  NATS.connect { |nc|
    nc.publish("api.#{App.first._id}")
  }
end
