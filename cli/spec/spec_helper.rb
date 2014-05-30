require 'rubygems'
require 'stringio'
require 'webmock/rspec'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "../"))
require 'lib/peas'

ENV['GLI_ENV'] = 'test'
ROOT = File.join(File.expand_path(File.dirname(__FILE__)), '..')
$LOAD_PATH.unshift(File.join(ROOT, 'lib'))
TEST_DOMAIN = 'http://localhost:4000'

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec
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
def response_mock response, key=:message
  {
    'version' => Peas::VERSION,
    key => response
  }.to_json
end

# Clever little function to simulate CLI requests.
# Usage: cli(['create', '--flag', '--switch']).
# Output is suppressed, captured and returned.
def cli args
  stub_const "ARGV", args
  capture_stdout do
    ENV['GLI_DEBUG'] = 'true'
    load File.join(ROOT, 'bin/peas')
  end
end
