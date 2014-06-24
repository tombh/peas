module Commands

  # Subscribe to a pubsub channel
  # Usage: subscribe.<channel_name>
  def subscribe
    # Everything after the first '.' is considered the channel name
    channel = @header[1..-1].join('.')
    debug "NEW SUBSCRIBER to #{channel}"
    # Send first time subscribers a copy of everything that's already happened
    publisher = Celluloid::Actor["publish.#{channel}"]
    if publisher
      history = publisher.channel_history
      history.each do |line|
        write_line line
      end if history
    end
    # `super` is used because Celluloid::Notification's pubsub also uses 'subscribe'
    super channel, :subscriber_callback
  end

  def subscriber_callback topic, message
    debug "SUB BROADCAST :: #{topic} - #{message}"
    write_line message
  end

end