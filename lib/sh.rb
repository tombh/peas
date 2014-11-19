require 'timeout'
require 'pty'

module Peas
  # Convenience wrapper for the command line.
  #   * Kills commands if they run too long
  #   * Can switch user before running the requested command
  def self.sh(command, timeout = 60, user: 'peas', tty: false)
    session = Shell.new tty
    session.su user if user != 'peas'
    session.command command, timeout: timeout
  end

  class Shell
    attr_accessor :read, :write

    def initialize(tty = false, initial_command = 'bash')
      if tty
        # TTY gives *very* raw output
        @read, @write, @pid = PTY.spawn initial_command
      else
        @read = @write = IO.popen(initial_command, mode: 'a+')
      end
    end

    def su(user)
      @write.puts "sudo -u #{user} /bin/bash"
    end

    def command(command, timeout: 60)
      output = []
      @write.puts "#{command} 2>&1; echo $?; echo 'PEAS_SH_COMPLETE'"
      begin
        Timeout.timeout(timeout) do
          @read.each_line do |line|
            if line.strip == 'PEAS_SH_COMPLETE'
              unless output.pop.strip == '0'
                raise Peas::PeasError, "`#{command}` failed with: \n--- \n #{output} \n---"
              end
              break
            end
            output << line
          end
          output = output.join.strip
        end
      rescue Timeout::Error
        raise Peas::PeasError, "`#{command}` timed out after #{timeout} seconds, " \
          "captured output: \n--- \n #{output} \n---"
      rescue Errno::EIO
        # Most likely means child has finished giving output
      end
      output
    ensure
      Process.kill 'SIGKILL', @pid if @pid
    end

    # Check to see if process is still running. Only applicable for TTY
    def running?
      PTY.check(@pid).nil?
    end
  end
end
