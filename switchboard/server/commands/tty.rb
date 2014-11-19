module Commands
  # Interact with a one-off app container
  def tty
    @socket.write "Starting one-off pea for #{@command[1]}..."

    # Create a remote container and get it to phone home via the Rendevous Switchboard command
    properties = {
      app: App.find_by(name: @command[1]),
      process_type: 'console'
    }
    tty_command = @socket.gets.strip
    unless tty_command == 'console'
      properties.merge!(
        process_type: 'one-off',
        command: "export HOME=/app; cd /app; for file in .profile.d/*.sh; do source $file; done; #{tty_command}"
      )
    end
    remote_pea = Pea.spawn(properties)
    remote_pea.worker.connect_to_rendevous

    # Wait until the remote container is up
    server_actor = Celluloid::Actor[:switchboard_server]
    sleep 0.1 while server_actor.rendevous[remote_pea.docker_id].nil?

    # Get the socket that the container has made from its remote pod
    remote_pea_socket = server_actor.rendevous[remote_pea.docker_id]

    @socket.write "done\r\n"

    # Join the sockets together
    async.plug_sockets @socket, remote_pea_socket
    async.plug_sockets remote_pea_socket, @socket

    # Wait until the session is ended by either the container or the user
    sleep 0.1 until @socket.closed? || remote_pea_socket.closed?
    remote_pea.worker.destroy
  end
end
