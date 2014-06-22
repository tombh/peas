module Commands

  # Subscribe to a pubsub channel
  # Usage: subscribe.<channel_name>
  def subscribe
    channel = @header[1]
    subscribe channel, :respond
  end

  private
  	def respond topic, message
      write_line message
  	end
end