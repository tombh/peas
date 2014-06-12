module Commands

  # Receives logs from docker containers and inserts them into a capped MongoDB collection
  def app_logs
    pea = Pea.find(@header[1])
    app = pea.app
    info "Request to archive logs for #{pea.name}@#{app.name}"
    loop do
      p "1"
      app.log read_line.chomp, pea.name
      p "2"
    end
  end
end