module Commands

  # Receives logs from docker containers and inserts them into a capped MongoDB collection
  def app_logs
    pea = Pea.find(@command[1])
    app = pea.app
    info "Request to archive logs for #{pea.name}@#{app.name}"
    loop do
      line = read_line.to_s.chomp.strip
      app.log(line, pea.name) if !line.empty?
      sleep 0.01
    end
  end
end