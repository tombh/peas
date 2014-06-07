Dir["#{Peas.root}/switchboard/server/commands/**/*.rb"].each { |f| require f }

# Handle individual connections to the Switchboard server
class Connection
  include Celluloid::IO
  include Celluloid::Logger
  include Commands

  def initialize socket
    @socket = socket

    _, @port, @host = socket.peeraddr
    info "Received connection (ID: #{@socket.object_id}) from #{@host}:#{@port}"

    # The first line of a request should contain something like:
    # 'app_logs.5389cf295a454e7d26000000.5390f5665a454e77990b0000'
    begin
      @header = @socket.readline.chomp.split('.')
    rescue EOFError
      return
    end
    command = @header[0]

    # Dynamically call the requested command as an instance method. But do a little sanity check
    # first. This could easily be abused :/
    if command.to_sym.in? Connection.instance_methods
      begin
        # All commands are kept at messaging/server/commands
        send(command)
      rescue EOFError
      end
    else
      warn "Uknown command requested in connection header"
    end

    close
  end

  # Check if the client is still there. Used for long-running client connections, like the log
  # tailer for example. Pops off a single byte every time it checks so don't use for clients that
  # actually send data you want to keep.
  def check
    loop { @socket.recv 1 }
  rescue EOFError, Errno::EPIPE
    info "Connection (ID: #{@socket.object_id}) detected as closed"
    close
  rescue IOError
    close
  end

  # Centralised means of closing the connection so it can be consistently logged.
  def close
    info "Closing connection (ID: #{@socket.object_id})" if !@socket.closed?
    @socket.close
  rescue IOError
  end

end
