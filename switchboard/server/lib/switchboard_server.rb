require 'config/boot'
require 'switchboard/server/lib/connection'
require 'celluloid/io'

class SwitchboardServer
  include Celluloid::IO
  include Celluloid::Logger

  # Ephemeral data store to archive activity on a pubsub channel
  # TODO: Garbage collect contents, perhaps by deleting channel key 30 mins after last activity?
  attr_accessor :channel_history, :rendevous

  def initialize(host, port)
    info "Starting Peas Switchboard Server on #{Peas.switchboard_server_uri}"

    # This allows us to do `Celluloid::Actor[:switchboard_server].channel_history[:channel_name]` etc,
    # from any connection.
    @channel_history = {}
    @rendevous = {}
    Celluloid::Actor[:switchboard_server] = Celluloid::Actor.current

    # Since we included Celluloid::IO, we're actually making a Celluloid::IO::TCPServer here
    @server = TCPServer.new(host, port)
    async.accept_connections
  end

  finalizer :finalize
  def finalize
    @server.close if @server
  end

  def accept_connections
    loop { async.handle_connection @server.accept }
  end

  def handle_connection(socket)
    debug "Current number of tasks: #{tasks.count}"
    connection = Connection.new socket
    # Because the connection actor isn't linked we don't have to worry about it crashing the server.
    # Any errors should be logged by the Connection object itself.
    connection.dispatch rescue nil
  end
end
