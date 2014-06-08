desc 'Show logs for an app'
command :logs do |c|
  c.action do |global_options, options, args|
    socket = API.switchboard_connection
    socket.puts "stream_logs.#{Git.first_sha}"
    begin
      while line = socket.gets
        puts line
      end
    rescue Interrupt
    end
  end
end
