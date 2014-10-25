require 'rubygems'
require 'stringio'
require 'webmock/rspec'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "../"))
require 'lib/peas'

ENV['GLI_ENV'] = 'test'
ROOT = File.join(File.expand_path(File.dirname(__FILE__)), '..')
$LOAD_PATH.unshift(File.join(ROOT, 'lib'))
TEST_DOMAIN = 'http://vcap.me:4000'
SWITCHBOARD_TEST_PORT = 79345

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec

  config.before(:each) do
    stub_const('Peas::SWITCHBOARD_PORT', SWITCHBOARD_TEST_PORT)
  end

  config.before(:each, :with_socket) do
    @socket = double 'TCPSocket'
    expect(@socket).to receive(:puts).with('subscribe.job_progress.123')
    allow(TCPSocket).to receive(:new).and_return(@socket)
  end

  config.before(:each, :with_echo_server) do
    @server = TCPServer.new 'vcap.me', SWITCHBOARD_TEST_PORT
    Thread.new do
      @connection = @server.accept
      begin
        Timeout.timeout(2) do
          while (line = @connection.gets)
            @connection.puts line
            @connection.close if line.strip == 'FINAL COMMAND'
          end
        end
      rescue Timeout::Error
        @connection.close
      end
    end
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
