require 'rubygems'
require 'net/http'
require 'webmock'
require 'vcr'
require_relative '../config/settings'

TMP_PATH = '/tmp/peas'
FileUtils.mkdir_p TMP_PATH

puts "\nRun `docker logs -f peas-test` to tail integration test activity\n\n"

# Find the test-specific data volume
def get_data_vol_id
  output = Peas.pty "docker ps -a | grep 'busybox:.*peas-data-test' | awk '{print $1}'"
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
  Peas.pty "docker run -v /var/lib/docker -v /data/db -v /var/lib/gems --name peas-data-test busybox true"
  if !get_data_vol_id
    raise "Failed to create data volume. Aborting."
  else
    return get_data_vol_id
  end
end

# Helper to run commands *inside* the running Peas test container
class ContainerConnection
  def initialize(container_id)
    @io = IO.popen "docker attach #{container_id} > /dev/null 2>&1", 'r+'
  end
  # Run a BASH command
  def bash(cmd)
    @io.puts cmd
  end
  # Run a command that you would normally run with the `rake console` IRB
  def console(cmd)
    bash 'cd /home/peas/repo && echo "%s" | bundle exec rake console' % cmd
  end
  # Reset DBs and docker ready for new tests
  def env_reset
    # TODO: need a way to check if these commands were successful
    bash "mongo peas --eval 'db.dropDatabase()'"
    bash "mongo nodejssample --eval 'db.dropDatabase()'"
    bash "mongo nodejssample --eval \"db.dropUser('nodejssample')\""
    bash "docker kill `docker ps -a -q` && docker rm `docker ps -a -q`"
    sleep 5
    # The test container runs on port 4004 to avoid conflicts with any dev/prod containers
    console "Setting.create(key: 'peas.domain', value: 'vcap.me:4004')"
    # Create a pod stub for the controller-pod combined setup
    console "ENV['PEAS_API_LISTENING'] = 'true'; Pod.create_stub"
  end
  # Close the connection
  def close
    @io.close
  end
end

def http_get(uri)
  unless uri[/\Ahttp:\/\//] || uri[/\Ahttps:\/\//]
    uri = "http://#{uri}"
  end
  Net::HTTP.get URI(uri)
end

class Cli
  def initialize(path)
    @path = path
  end

  # Helper to call Peas CLI
  def run(cmd, timeout = 60)
    cmd = "cd #{@path} && " \
      "HOME=/tmp/peas " \
      "PEAS_API_ENDPOINT=vcap.me:4004 " \
      "SWITCHBOARD_PORT=7345 " \
      "#{Peas.root}cli/bin/peas-dev #{cmd}"
    Peas.pty cmd, timeout
  end

  def sh(cmd)
    Peas.pty "cd #{@path} && #{cmd}"
  end
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec

  # Create the Peas container against which the CLI client will interact
  config.before(:all, :integration) do
    WebMock.allow_net_connect!
    VCR.turn_off!
    setup_data_volume
    @peas_container_id = Peas.pty(
      "docker run -d \
        --privileged \
        -i \
        --name peas-test \
        --volumes-from peas-data-test \
        -v #{Peas.root}:/home/peas/repo \
        -p 4004:4000 \
        -p 7345:9345 \
        -e PEAS_ENV=production \
        tombh/peas"
    )
    # Wait until the container has completely booted
    Timeout.timeout(4 * 60) do
      result = `bash -c \
        'until [ "$(curl -s -o /dev/null -w "%{http_code}" localhost:4004)" == "200" ]; do \
          sleep 1;
        done' 2>&1`
      raise result if $CHILD_STATUS.to_i != 0
    end
    # Open an IO pipe to the launched container
    @peas_io = ContainerConnection.new @peas_container_id

    # Clone a very basic NodeJS app
    REPO_PATH = TMP_PATH + '/node-js-sample'
    Peas.pty "rm -rf #{REPO_PATH}"
    Peas.pty "cd #{TMP_PATH} && git clone https://github.com/tombh/node-js-sample.git"

    # Just to make sure everything is clean before we start
    @peas_io.env_reset
  end

  config.before(:each, :integration) do |example|
    # Don't reset state between specs if explicitly told not to
    unless example.metadata.key? :maintain_test_env
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
    Peas.pty "docker logs #{@peas_container_id} > #{TMP_PATH}/integration-tests.log 2>&1"
    # Remove the Peas test container. But the data container 'peas-data-test' still remains
    Peas.pty "docker stop #{@peas_container_id}"
    Peas.pty "docker rm -f #{@peas_container_id}"
    puts ""
    puts "Integration tests log available at #{TMP_PATH}/integration-tests.log"
    WebMock.disable_net_connect!
    VCR.turn_on!
  end
end
