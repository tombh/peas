module Commands
  # Broker a connection between the CLI `run` command and a one-off container running in a different pod
  def rendevous
    docker_id = @command[1]
    server_actor = Celluloid::Actor[:switchboard_server]
    server_actor.rendevous[docker_id] = @socket
    sleep 1 until @socket.closed?
  end
end
