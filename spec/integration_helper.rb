require 'rubygems'
require 'timeout'
require 'pty'
require 'net/http'
require 'webmock'
require 'vcr'
require_relative '../config/settings'

TMP_PATH = '/tmp/peas'
FileUtils.mkdir_p TMP_PATH

puts "\nRun `docker logs -f peas-test` to tail integration test activity\n\n"

# Convenience wrapper for the command line. Kills commands if they run too long
# Note that `curl` seems to behave oddly with this -  it doesn't output anything
def sh command, timeout = 60
  output = ''
  pid = nil
  PTY.spawn(command  + ' 2>&1') do |stdout, stdin, pid_local|
    pid = pid_local
    begin
      Timeout::timeout(timeout) do
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
  if !status.nil?
    if status.exitstatus != 0
      raise "`#{command}` failed with: \n--- \n #{output} \n---"
    end
  end
  output.strip! if output.lines.count == 1
  return output
end

# Find the test-specific data volume
def get_data_vol_id
  output = sh "docker ps -a | grep 'busybox:.*peas-data-test' | awk '{print $1}'"
  if output.length == 12 # Trivial sanity check
    output
  else
    false
  end
end

# Find or create the test-specific data volume
def setup_data_volume
  return get_data_vol_id if get_data_vol_id
  # Name the volume differently from the one that may be used in dev/prod
  sh "docker run -v /var/lib/docker -v /data/db -v /var/lib/gems --name peas-data-test busybox true"
  if !get_data_vol_id
    raise "Failed to create data volume. Aborting."
  else
    return get_data_vol_id
  end
end

# Helper to run commands *inside* the running Peas test container
class ContainerConnection
  def initialize container_id
    @io = IO.popen "docker attach #{container_id} > /dev/null 2>&1", 'r+'
  end
  # Run a BASH command
  def bash cmd
    @io.puts cmd
  end
  # Run a command that you would normally run with the `rake console` IRB
  def console cmd
    bash "cd /home/peas && echo '#{cmd}' | bundle exec rake console"
  end
  # Reset DBs and docker ready for new tests
  def env_reset
    # TODO: need a way to check if these commands were successful
    bash "mongo peas --eval 'db.dropDatabase();'"
    bash "redis-cli FLUSHALL"
    bash "docker kill `docker ps -a -q` && docker rm `docker ps -a -q`"
    sleep 2
    # The test container runs on port 4004 to avoid conflicts with any dev/prod containers
    console 'Setting.create(key: "domain", value: "vcap.me:4004")'
  end
  # Close the connection
  def close
    @io.close
  end
end

def http_get uri
  unless uri[/\Ahttp:\/\//] || uri[/\Ahttps:\/\//]
    uri = "http://#{uri}"
  end
  Net::HTTP.get URI(uri)
end

class Cli
  def initialize path
    @path = path
  end

  # Helper to call Peas CLI
  def run cmd, timeout = 60
    cmd = "cd #{@path} && " +
      "HOME=/tmp/peas " +
      "PEAS_API_ENDPOINT=localhost:4004 " +
      "SWITCHBOARD_PORT=7345 " +
      "#{Peas.root}cli/bin/peas-dev #{cmd}"
    sh cmd, timeout
  end
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec
  config.filter_run_excluding :integration => true unless ENV['ONE']

  # Create the Peas container against which the CLI client will interact
  config.before(:all, :integration) do
    WebMock.allow_net_connect!
    VCR.turn_off!
    setup_data_volume
    @peas_container_id = sh(
      "docker run -d \
        --privileged \
        -i \
        --name peas-test \
        --rm=true \
        --volumes-from peas-data-test \
        -v #{Peas.root}:/home/peas \
        -p 4004:4000 \
        -p 7345:9345 \
        -e RACK_ENV=production \
        tombh/peas"
    )
    # Wait until the container has completely booted
    Timeout::timeout(4*60) do
      result = `bash -c 'until [ "$(curl -s localhost:4004)" == "Not Found" ]; do sleep 1; done' 2>&1`
      raise result if $?.to_i != 0
    end
    # Open an IO pipe to the launched container
    @peas_io = ContainerConnection.new @peas_container_id

    # Clone a very basic NodeJS app
    REPO_PATH = TMP_PATH + '/node-js-sample'
    sh "rm -rf #{REPO_PATH}"
    sh "cd #{TMP_PATH} && git clone https://github.com/tombh/node-js-sample.git"

    # Just to make sure everything is clean before we start
    @peas_io.env_reset
  end

  config.before(:each, :integration) do |example|
    # Don't reset state between specs if explicitly told not to
    if !example.metadata.has_key? :maintain_test_env
      # Reset state after each spec
      @peas_io.env_reset
    end
  end

  # But do reset state before a series of :maintain_test_env specs
  config.before(:all, :maintain_test_env) do
    @peas_io.env_reset
  end

  # Destroy the Peas container
  config.after(:all, :integration) do
    @peas_io.bash "mongod --shutdown"
    @peas_io.close
    # Save logs before destroying
    sh "docker logs #{@peas_container_id} > #{TMP_PATH}/integration-tests.log 2>&1"
    # Remove the Peas test container. But the data container 'peas-data-test' still remains
    sh "docker stop #{@peas_container_id}"
    sh "docker rm -f #{@peas_container_id}"
    puts ""
    puts "Integration tests log available at #{TMP_PATH}/integration-tests.log"
    WebMock.disable_net_connect!
    VCR.turn_on!
  end
end
