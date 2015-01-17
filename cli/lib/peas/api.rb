require 'httparty'
require 'socket'
require 'openssl'

class API
  include HTTParty
  # TODO: Don't want to ignore genuine SSL cert errors, say if there's a CA root cert
  default_options.update(verify: false) # Ignore self-signed SSL error

  LONG_POLL_TIMEOUT = 10 * 60
  LONG_POLL_INTERVAL = 0.5

  # This allows base_uri to be dynamically set. Useful for testing
  def initialize
    self.class.base_uri Peas.api_domain
  end

  # Generic wrapper to the Peas API
  # `verb` HTTP verb
  # `method` API method, eg; /app/create
  # `query` Query params
  # `auth` Whether to authenticate against the API. Eg; /auth/request doesn't need auth
  # `print` Whether to output or return the response
  def request(verb, method, query = {}, auth = true, print = true)
    options = { query: query }
    options[:headers] = { 'x-api-key' => api_key } if auth
    request = [
      verb.to_s.downcase,
      "#{method}",
      options
    ]
    response = self.class.send(request.shift, *request).body
    json = response ? JSON.parse(response) : {}
    # If there was an HTTP-level error
    raise json['error'].color(:red) if json.key? 'error'
    # Successful responses
    if json.key? 'job'
      # Long-running jobs need to stream from the Switchboard server
      API.stream_job json['job']
    else
      check_versions(json)
      puts json['message'] if print
      json
    end
  end

  # Get the API key from local cache, or request a new one
  def api_key
    # First check local storage
    key = Peas.config['api_key']
    return key if key
    # Other wise request a new one
    key_path = "#{ENV['HOME']}/.ssh/id_rsa"
    unless File.exist? key_path
      exit_now! 'Please add an SSH key'
    end
    username = ENV['USER'] # TODO: Ensure cross platform
    params = {
      username: username,
      public_key: File.read("#{key_path}.pub")
    }
    response = request('POST', '/auth/request', params, auth: false, print: false)
    doc = response['message']['sign']
    digest = OpenSSL::Digest::SHA256.new
    keypair = OpenSSL::PKey::RSA.new(File.read(key_path))
    signature = keypair.sign(digest, doc)
    encoded = Base64.urlsafe_encode64(signature)
    params = {
      username: username,
      signed: encoded
    }
    response = request('POST', '/auth/verify', params, auth: false, print: false)
    key = response['message']['api_key']
    Peas.update_config api_key: key
    key
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
    socket = TCPSocket.new Peas.host, Peas::SWITCHBOARD_PORT
    ssl = OpenSSL::SSL::SSLSocket.new socket
    ssl.sync_close = true
    ssl.connect
    ssl.puts API.new.api_key
    unless ssl.gets.strip == 'AUTHORISED'
      ssl.close
      raise 'Unauthoirsed access to Switchboard connection.'
    end
    ssl
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
  def self.duplex_socket(socket)
    threads = []

    # Copy STDIN to socket
    threads << Thread.start do
      STDIN.raw do |stdin|
        IO.copy_stream stdin, socket
      end
      socket.close
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
