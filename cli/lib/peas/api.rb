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
  def request verb, method, params = nil
    response = self.class.send(verb, "#{method}", {query: params}).body
    if response
      json = JSON.parse(response)
    else
      json = {}
    end
    # If there was an HTTP-level error
    raise json['error'].color(:red) if json.has_key? 'error'
    # Successful responses
    if json.has_key? 'job'
      # Long-running jobs need to stream from the Switchboard server
      stream_output "subscribe.job_progress.#{json['job']}"
    else
      # Check CLI client is up to date.
      # Only check major and minor versions
      version_mismatch = false
      api_version = json['version'].split('.')
      client_version = Peas::VERSION.split('.')
      if api_version[0] != client_version[0]
        version_mismatch = true
      else
        if api_version[1] != client_version[1]
          version_mismatch = true
        end
      end
      if version_mismatch
        Peas.warning_message "Your version of the CLI client is out of date " +
          "(Client: #{Peas::VERSION}, API: #{json['version']}). " +
          "Please update using `gem install peas-cli`."
      end
      # Normal API response
      puts json['message']
    end
  end

  def self.switchboard_connection
    TCPSocket.new Peas.host, Peas::SWITCHBOARD_PORT
  end

  # Stream data from the Switchboard server, usually the progress of a worker job
  def stream_output switchboard_command
    socket = API.switchboard_connection
    socket.puts switchboard_command
    begin
      while line = socket.gets
        puts line
      end
    rescue Interrupt, Errno::ECONNRESET
    end
  end

end