module Commands
  def logs
    app = App.find(@header[1])
    pea = Pea.find(@header[2])
    loop do
      line = "#{DateTime.now} app[#{pea.process_type}.#{pea.process_number}]: #{@socket.readline.chomp}"
      app_logs_collection = Mongoid::Sessions.default["#{app.first_sha}_logs"]
      app_logs_collection.insert({line: line})
    end
  end
end