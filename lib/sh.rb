require 'timeout'

module Peas
  # Convenience wrapper for the command line.
  #   * Kills commands if they run too long
  #   * Can switch user before running the requested command
  def self.sh(command, timeout = 60, user: 'peas')
    session = Shell.new
    session.command "sudo su - #{user}" if user != 'peas'
    session.command command, timeout: timeout
  end

  class Shell
    def initialize
      @io = IO.popen('bash', mode: 'a+')
    end

    def command(command, timeout: 60)
      output = []
      status = nil
      @io.puts "#{command} 2>&1; echo $?; echo 'PEAS_SH_COMPLETE'"
      begin
        Timeout.timeout(timeout) do
          @io.each_line do |line|
            if line.strip == 'PEAS_SH_COMPLETE'
              status = output.pop.strip
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
      unless status == '0'
        raise Peas::PeasError, "`#{command}` failed with: \n--- \n #{output} \n---"
      end
      output.lines.first.strip! if output.lines.count == 1
      output
    end
  end
end
