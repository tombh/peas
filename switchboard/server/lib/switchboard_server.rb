require 'config/boot'
require 'openssl'
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

    create_server host, port
    async.accept_connections
  end

  finalizer :finalize
  def finalize
    @server.close if @server
  end

  def accept_connections
    loop do
      begin
        async.handle_connection @server.accept
      rescue => e
        error e
      end
    end
  end

  def handle_connection(socket)
    debug "Current number of tasks: #{tasks.count}"
    connection = Connection.new socket
    # Because the connection actor isn't linked we don't have to worry about it crashing the server.
    # Any errors should be logged by the Connection object itself.
    connection.dispatch rescue nil
  end

  def create_server(host, port)
    tcp_server = Celluloid::IO::TCPServer.new host, port
    context = OpenSSL::SSL::SSLContext.new
    context.key = Peas::SSL_KEY
    context.cert = Peas::SSL_CERT
    @server = Celluloid::IO::SSLServer.new tcp_server, context
  end
end
