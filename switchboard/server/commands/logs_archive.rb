module Commands
  def logs
    app = App.find(@header[1])
    pea = Pea.find(@header[2])
    info "Request to archive logs for #{pea.name}@#{app.name}"
    loop do
      app.log @socket.readline.chomp, pea.name
    end
  end
end