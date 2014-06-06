require 'config/boot'
require 'messaging/server/connection'
require 'celluloid/io'

class MessageServer
  include Celluloid::IO

  def initialize host, port
    puts "*** Starting message server on #{host}:#{port}"

    # Since we included Celluloid::IO, we're actually making a
    # Celluloid::IO::TCPServer here
    @server = TCPServer.new(host, port)
    async.run
  end

  finalizer :finalize
  def finalize
    @server.close if @server
  end

  def run
    loop { async.handle_connection @server.accept }
  end

  # Note how the socket has to be passed around as a method argument. Instance variables in a
  # concurrent Celluloid object are shared between threads. If you store each connection socket as
  # instance variable then it gets overwritten by each new connection.
  def handle_connection socket
    puts "Current number of tasks: #{tasks.count}"
    connection = Connection.new socket
    connection.close
  rescue => exception
    puts "#{exception.class} :: #{exception.message} #{exception.backtrace.first}"
    socket.close
  end

end