require 'switchboard/server/lib/log_cursor'

module Commands

  # Stream and tail logs for an app
  def stream_logs
    app = App.find_by(first_sha: @command[1])
    info "Request to stream logs for #{app.name} on connection (ID: #{@socket.object_id})"
    logs = LogsCursor.new app

    # Stream the existing logs
    logs.existing do |line|
      write_line line
    end

    # Wait for more logs to be added to the DB and stream them back when they are
    loop do
      logs.more{ |line| write_line line }
      sleep 0.01 # Needed to allow Celluloid to pass flow control elsewhere
    end
  end

end
