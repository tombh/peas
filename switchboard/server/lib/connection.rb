require 'celluloid/autostart' # for Celluloid::Notifications

Dir["#{Peas.root}/switchboard/server/commands/**/*.rb"].each { |f| require f }

# Handle individual connections to the Switchboard server
class Connection
  include Celluloid::IO
  include Celluloid::Logger
  include Celluloid::Notifications # pubsub
  include Commands # user-added commands

  # Amount of time to pass without any socket activity before terminating the thread
  INACTIVITY_TIMEOUT = 30*60

  def initialize socket
    @socket = socket
    # Safety measure to kill the thread if nothing happens for a while.
    # You can reset the timer by calling activity()
    @timer = after(INACTIVITY_TIMEOUT) { terminate }
  end

  def dispatch
    _, @port, @host = @socket.peeraddr
    debug "Received connection (ID: #{@socket.object_id}) from #{@host}:#{@port}"

    # The first line of a request should contain something like:
    # 'app_logs.5390f5665a454e77990b0000 option1 option2'
    begin
      response = read_line
      return if response.nil? # Most likely Peas checking if the server's up
    rescue EOFError
      return
    end

    response.strip!
    # Split by the first space character to get;
    # ['app_logs.5390f5665a454e77990b0000', 'option1 option2']
    parts = response.split(' ', 2)
    # Get the command, eg; ['app_logs', '5390f5665a454e77990b0000']
    @command = parts[0].split('.')
    # Get the options, eg; ['option1', 'option2']
    @options = parts[1] ? parts[1].split(' ') : []
    # The actual method to call, so; 'app_logs' in this example
    method = @command[0]

    # Dynamically call the requested method as an instance method. But do a little sanity check
    # first. This could easily be abused :/
    if method.to_sym.in? Commands.instance_methods
      # All commands are kept at switchboard/server/commands
      async.send(method)
    else
      warn "Uknown command requested in connection header"
    end
  end

  # Resets the inactivity timer
  def activity
    @timer.reset
  end

  # Check if the client is still there. Used for long-running client connections, like the log
  # tailer for example. Pops off a single byte every time it checks so don't use for clients that
  # actually send data you want to keep.
  def check
    loop { read_partial }
  end

  # Centralised means of closing the connection so it can be consistently logged.
  def close type = :normal
    if !@socket.closed?
      info "Closing connection (ID: #{@socket.object_id}) #{'(closed via client)' if type == :detected}"
    end
    @socket.close
  rescue IOError
  end

  # Read a fixed number of bytes from the incoming connection
  def read_partial bytes = 1
    data = io{ @socket.recv bytes }
    if data
      yield data if block_given?
      return data
    end
  end

  # Read a line from the incoming connection
  def read_line
    line = io{ @socket.gets }
    if line
      yield line if block_given?
      return line
    end
  end

  # Write a line to the incoming connection
  def write_line line
    io{ @socket.puts line }
  end

  # Centralised means of carrying out IO on the socket. Useful for keeping behaviour in one place.
  def io &block
    begin
      response = yield
      activity
      return response
    rescue EOFError, Errno::EPIPE, IOError, Errno::EBADF
      close :detected
      return false
    end
  end
end
