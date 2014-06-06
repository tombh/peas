module Commands
  # This is a potentially leaky request as it reads from the log store indefinitely. So make
  # sure it's killed when the requesting connection dissapears.
  def api
    async.check
    app = App.find(@header[1])
    puts "Request to stream logs for #{app.name}"
    logs = LogsCursor.new app
    logs.existing do |line|
      @socket.puts line
    end
    loop do
      break if @socket.closed?
      logs.more do |line|
        @socket.puts line
      end
      sleep 0.01 # Releases this thread to run the async.check thread for a bit
    end
  end
end
