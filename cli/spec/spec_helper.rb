require 'stringio'
require 'rubygems'
require 'webmock/rspec'
require 'openssl'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "../"))
require 'lib/peas'

ENV['GLI_ENV'] = 'test'
ROOT = File.join(File.expand_path(File.dirname(__FILE__)), '..')
$LOAD_PATH.unshift(File.join(ROOT, 'lib'))
TEST_DOMAIN = 'https://vcap.me:4000'
SWITCHBOARD_TEST_PORT = 79345
SSL_KEY_PATH = "#{ROOT}/../contrib/ssl-keys/server.key"
SSL_KEY = OpenSSL::PKey::RSA.new File.read(SSL_KEY_PATH)
SSL_CERT_PATH = "#{ROOT}/../contrib/ssl-keys/server.crt"
SSL_CERT = OpenSSL::X509::Certificate.new File.read(SSL_CERT_PATH)

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec

  config.before(:each) do
    stub_const('Peas::SWITCHBOARD_PORT', SWITCHBOARD_TEST_PORT)
  end

  config.before(:each, :with_socket) do
    tcp = instance_double TCPSocket
    allow(TCPSocket).to receive(:new).and_return(tcp)
    @socket = instance_double OpenSSL::SSL::SSLSocket
    allow(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(@socket)
    allow(@socket).to receive(:sync_close=)
    allow(@socket).to receive(:connect)
  end

  config.before(:each, :with_echo_server) do
    tcp_server = TCPServer.new 'vcap.me', SWITCHBOARD_TEST_PORT
    context = OpenSSL::SSL::SSLContext.new
    context.key = SSL_KEY
    context.cert = SSL_CERT
    Thread.new do
      @server = OpenSSL::SSL::SSLServer.new tcp_server, context
      @connection = @server.accept
      begin
        Timeout.timeout(2) do
          while (line = @connection.gets)
            @connection.write line
            @connection.close if line.strip == 'FINAL COMMAND'
          end
        end
      rescue Timeout::Error
      ensure
        @connection.close
      end
    end
  end

  config.after(:each, :with_echo_server) do
    @server.close rescue nil
  end

end

# Execute a block that triggers STDOUT and test output
def capture_stdout(&blk)
  old = $stdout
  $stdout = fake = StringIO.new
  blk.call
  fake.string
ensure
  $stdout = old
end

# Form a response as the API would. Useful as you only need to provide a string without any JSON
# formatting
def response_mock(response, key = :message)
  {
    'version' => Peas::VERSION,
    key => response
  }.to_json
end

# Clever little function to simulate CLI requests.
# Usage: cli(['create', '--flag', '--switch']).
# Output is suppressed, captured and returned.
def cli(args)
  stub_const "ARGV", args
  capture_stdout do
    ENV['GLI_DEBUG'] = 'true'
    load File.join(ROOT, 'bin/peas')
  end
end
