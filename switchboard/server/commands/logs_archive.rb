module Commands
  # Receives logs from docker containers and inserts them into a capped MongoDB collection
  def app_logs
    @keep_alive = true # Prevent connection dying from inactivity
    pea = Pea.find(@command[1])
    app = pea.app
    info "Request to archive logs for #{pea.name}@#{app.name}"
    loop do
      line = read_line.to_s.chomp.strip
      app.log(line, pea.name) unless line.empty?
      sleep 0.01
    end
  end
end
