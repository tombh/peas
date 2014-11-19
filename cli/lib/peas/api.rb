require 'httparty'
require 'socket'

class API
  include HTTParty

  LONG_POLL_TIMEOUT = 10 * 60
  LONG_POLL_INTERVAL = 0.5

  # This allows base_uri to be dynamically set. Useful for testing
  def initialize
    self.class.base_uri Peas.api_domain
  end

  # Generic wrapper to the Peas API
  def request(verb, method, params = nil)
    response = self.class.send(verb, "#{method}", query: params).body
    json = response ? JSON.parse(response) : {}
    # If there was an HTTP-level error
    raise json['error'].color(:red) if json.key? 'error'
    # Successful responses
    if json.key? 'job'
      # Long-running jobs need to stream from the Switchboard server
      API.stream_job json['job']
    else
      check_versions(json)
      if block_given?
        yield json['message']
      else
        puts json['message']
      end
      json
    end
  end

  # Check CLI client is up to date.
  def check_versions(json)
    # Only check major and minor versions
    version_mismatch = false
    api_version = json['version'].split('.')
    client_version = Peas::VERSION.split('.')
    if api_version[0] != client_version[0]
      version_mismatch = true
    else
      version_mismatch = true if api_version[1] != client_version[1]
    end
    return unless version_mismatch
    Peas.warning_message "Your version of the CLI client is out of date " \
      "(Client: #{Peas::VERSION}, API: #{json['version']}). " \
      "Please update using `gem install peas-cli`."
  end

  def self.switchboard_connection
    TCPSocket.new Peas.host, Peas::SWITCHBOARD_PORT
  end

  # Stream the output of a Switchboard job
  def self.stream_job(job)
    API.stream_output "subscribe.job_progress.#{job}" do |line|
      if line.key? 'status'
        if line['status'] == 'failed'
          raise line['body']
        elsif line['status'] == 'complete'
          break
        end
      end
      puts line['body'] if line['body']
    end
  end

  # Stream data from the Switchboard server
  def self.stream_output(switchboard_command)
    socket = API.switchboard_connection
    socket.puts switchboard_command
    begin
      while (line = socket.gets)
        if block_given?
          yield JSON.parse line
        else
          puts line
        end
      end
    rescue Interrupt, Errno::ECONNRESET
    end
  end

  # Create 2 threads to allow raw TTY to be sent at the same time as outputting
  # data from the socket.
  def self.duplex_socket socket
    threads = []

    # Copy STDIN to socket
    threads << Thread.start do
      STDIN.raw do |stdin|
        IO.copy_stream stdin, socket
      end
      socket.close_write
    end

    # Write response to STDOUT
    threads << Thread.start do
      begin
        while (chunk = socket.readpartial(512))
          print chunk
        end
      rescue EOFError
      end
      threads.first.kill
    end

    threads.each(&:join)
  end
end
