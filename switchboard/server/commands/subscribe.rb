 module Commands

  # Subscribe to a pubsub channel
  # Usage: subscribe.<channel_name>
  def subscribe
    # Everything after the first '.' is considered the channel name
    channel = @header[1..-1].join('.')
    # `super` is used because Celluloid::Notification's pubsub also uses 'subscribe'
    super channel, :subscriber_callback
  end

	def subscriber_callback topic, message
    debug "SUB :: #{topic} - #{message}"
    write_line message
	end

end