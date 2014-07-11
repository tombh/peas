module Commands
  # Publish a message to a pubsub channel
  # By specfiying 'history' all publsihed data will be stored. So that first-time subscribers can
  # retrieve it.
  # Usage: `publish.channel_name [history]`
  #        `message_body`
  # Eg;
  # socket.puts 'publish.world_cup_results'
  # socket.puts '{spain: 1, netherlands: 5}'
  def publish
    # Everything after the first '.' is considered the channel name
    channel = @command[1..-1].join('.')

    # Prepare the channel data store for writing
    server_actor = Celluloid::Actor[:switchboard_server]
    server_actor.channel_history[channel] ||= []

    # The JSON for the message body is sent on subsequent lines of the socket connection (the header having
    # already been read on the first line)
    # `super` is used because Celluloid::Notification's pubsub also uses 'publish' as its method name
    while message = read_line
      debug "PUB SENT :: #{channel} - #{message}"
      server_actor.channel_history[channel] << message if @options.include? 'history'
      super channel, message
    end
  end
end
