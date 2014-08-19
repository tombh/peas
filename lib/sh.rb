require 'timeout'
require 'pty'

module Peas
  # Convenience wrapper for the command line. Kills commands if they run too long
  # Note that `curl` seems to behave oddly with this - it doesn't output anything
  def self.pty(command, timeout = 60, user: 'peas')
    output = ''
    pid = nil
    command = "sudo -u #{user} bash -c '#{command}'" unless user == 'peas'
    PTY.spawn(command  + ' 2>&1') do |stdout, _stdin, pid_local|
      pid = pid_local
      begin
        Timeout.timeout(timeout) do
          stdout.each do |line|
            output += line
          end
        end
      rescue Timeout::Error
        Process.kill('INT', pid)
      rescue Errno::EIO
        # Most likely means child has finished giving output
      end
    end
    status = PTY.check(pid)
    unless status.nil?
      if status.exitstatus != 0
        raise "`#{command}` failed with: \n--- \n #{output} \n---"
      end
    end
    output.strip! if output.lines.count == 1
    output
  end
end
