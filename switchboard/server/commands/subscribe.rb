module Commands

  # Subscribe to a pubsub channel
  # Using 'history' means that all existing publishe data on the channel is sent back with the first
  # request.s
  # Usage: subscribe.channel_name [history]
  def subscribe
    # Everything after the first '.' is considered the channel name
    channel = @command[1..-1].join('.')
    debug "NEW SUBSCRIBER to #{channel}"
    # Don't respond with historical data unless explicitly told so. For instance it would be bad
    # to send all the old jobs on a job queue to a job listener. But it is useful to send
    # existing job progress data.
    if @options.include? 'history'
      # Send first time subscribers a copy of everything that's already happened
      channel_history = Celluloid::Actor[:switchboard_server].channel_history
      if channel_history.has_key? channel
        channel_history[channel].each do |line|
          write_line line
        end
      end
    end
    # `super` is used because Celluloid::Notification's pubsub also uses 'subscribe'
    super channel, :subscriber_callback
  end

  def subscriber_callback topic, message
    debug "SUB BROADCAST :: #{topic} - #{message}"
    write_line message
  end

end