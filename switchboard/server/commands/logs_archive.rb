module Commands

  # Receives logs from docker containers and inserts them into a capped MongoDB collection
  def app_logs
    pea = Pea.find(@header[1])
    app = pea.app
    info "Request to archive logs for #{pea.name}@#{app.name}"
    read_line do |line|
      app.log line.chomp, pea.name
    end
  end
end