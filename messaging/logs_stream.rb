require_relative '../config/boot'
require 'socket'

socket = TCPSocket.new 'localhost', 4444

at_exit do
  puts "11"
  socket.close
end

socket.puts "api.#{App.find_by(name: 'node-js-sample')._id}"

while line = socket.gets
  puts line
end

socket.close

