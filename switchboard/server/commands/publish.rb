module Commands

  attr_accessor :channel_history

  # Publish a message to a pubsub channel
  # Usage: publish.<channel_name>\n<message_body>
  # Eg;
  # socket.puts 'publish.world_cup_results'
  # socket.puts '{spain: 1, netherlands: 5}'
  def publish
    @channel_history ||= []

    # Everything after the first '.' is considered the channel name
    channel = @header[1..-1].join('.')
    # The JSON for the message body is sent on subsequent lines of the socket connection (the header having
    # already been read on the first line)
    # `super` is used because Celluloid::Notification's pubsub also uses 'publish' as its method name
    while message = read_line do
      debug "PUB :: #{channel} - #{message}"
      @channel_history << message
      puts Celluloid::Actor['publish.jobs_for.controller'].channel_history
      super channel, message
    end
  end
end