module Commands
  # Interact with the Peas Controller
  def admin_tty
    @socket.write "Connecting to Peas Controller..."
    initial_command = read_line
    shell_pipe = Peas::Shell.new true, initial_command
    @socket.write "done\r\n"

    # Join the sockets together
    # Can't use plug_sockets() here because shell_pipe doesn't use a socket and
    # therefore Cellluloid::IO has no power over it :(
    shell_reader = Thread.new do
      loop do
        data = shell_pipe.read.readpartial(512)
        @socket.write data
      end
    end

    # async.plug_sockets shell_pipe.read, @socket
    async.plug_sockets @socket, shell_pipe.write

    # Wait until the session is ended by either the container or the user
    sleep 0.1 until @socket.closed? || !shell_pipe.running?
    shell_reader.kill
    @socket.close
  end
end
