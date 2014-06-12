require 'switchboard/server/lib/log_cursor'

module Commands

  # Stream and tail logs for an app
  def stream_logs
    app = App.find_by(first_sha: @header[1])
    info "Request to stream logs for #{app.name} on connection (ID: #{@socket.object_id})"
    logs = LogsCursor.new app

    # Stream the existing logs
    logs.existing do |line|
      write_line line
      sleep 0.2
    end

    # This is a potentially leaky block as it reads from the log store indefinitely. So we need
    # to make sure it's killed when the requesting connection dissapears.
    async.check
    loop do
      break if @socket.closed?
      logs.more do |line|
        write_line line
      end
    end
  end

end
