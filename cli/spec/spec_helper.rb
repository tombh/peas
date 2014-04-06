require 'rubygems'
require 'stringio'
require 'webmock/rspec'
require 'peas'

ENV['GLI_ENV'] = 'test'
ROOT = File.join(File.expand_path(File.dirname(__FILE__)), '..')
$LOAD_PATH.unshift(File.join(ROOT, 'lib'))

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
