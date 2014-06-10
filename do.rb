module Commands
  def fake; end
  def sleep
    sleep 0.1
  end
  def raise_exception
    raise
  end
  def echo
    while incoming = @socket.gets
      @socket.puts incoming
    end
  end
  def ping
    @socket.puts 'pong'
  end
end

require_relative 'config/boot'
require_relative 'switchboard/server/lib/switchboard_server'

server = SwitchboardServer.new 'localhost', 10000
client = TCPSocket.new 'localhost', 10000
client.puts "raise_exception"
client.puts "raise_exception"

sleep
