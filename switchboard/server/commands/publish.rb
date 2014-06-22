module Commands

  # Publish a message to a pubsub channel
  # Usage: publish.<channel_name>\n<message_body>
  # Eg;
  # socket.puts 'publish.world_cup_results'
  # socket.puts '{spain: 1, netherlands: 5}'
  def publish
    channel = @header[1]
    # The JSON for the message body is sent on subsequent lines of the socket connection (the header having
    # already been read on the first line)
    while message = read_line do
      publish channel, message
    end
  end
end