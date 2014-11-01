require 'rubygems'
require 'net/http'
require 'webmock'
require 'vcr'
require 'docker'
require_relative '../config/settings'
require_relative '../lib/sh'
require_relative '../lib/error'

TMP_PATH = '/tmp/peas'
FileUtils.mkdir_p TMP_PATH

puts "\nRun `docker logs -f peas-test` to tail integration test activity\n\n"

# Find the test-specific data volume
def get_data_vol_id
  output = Peas.sh "docker ps -a | grep 'busybox:.*peas-data-test' | awk '{print $1}'"
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
  Peas.sh "docker run \
    -v /var/lib/docker \
    -v /data/db \
    -v /home/peas/.bundler \
    -v /home/git \
    --name peas-data-test \
    busybox true"
  if !get_data_vol_id
    raise "Failed to create data volume. Aborting."
  else
    return get_data_vol_id
  end
end

# Helper to run commands *inside* the running Peas test container
class ContainerConnection
  attr_accessor :io
  def initialize(container_id)
    @io = IO.popen "docker attach #{container_id} 2>&1", 'r+'
    @io.puts "source /home/peas/.profile"
  end
  # Run a BASH command
  def bash(cmd)
    @io.puts cmd
  end
  # Run a command that you would normally run with the `rake console` IRB
  def console(cmd)
    marker = Time.now.to_f.to_s
    # The actual command is echoed, so if we matched an unconcatenated string we'd match the echo
    # and not the result.
    cmd = "#{cmd}; puts 'CONSOLE' + 'COMMAND' + '#{marker}'"
    bash 'cd /home/peas/repo && echo "%s" | bundle exec rake console' % cmd
    output = []
    loop do
      output << @io.gets
      break if output.last =~ %r{CONSOLECOMMAND#{marker}}
    end
    output.join
  end
  # Reset DBs and docker ready for new tests
  def env_reset
    # TODO: need a way to check if these commands were successful
    bash "mongo peas --eval 'db.dropDatabase()'"
    bash "mongo nodejssample --eval 'db.dropDatabase()'"
    bash "mongo nodejssample --eval \"db.dropUser('nodejssample')\""
    bash "docker kill `docker ps -a -q` && docker rm `docker ps -a -q`"
    bash "su git -c 'rm -rf /home/git/node-js-sample.git'"
    bash "su git -c 'cat /dev/null > /home/git/.ssh/authorized_keys'"
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

  # Helpers to call Peas CLI client
  def base_cmd
    cmd = "cd #{@path} && " \
      "HOME=/tmp/peas " \
      "PEAS_API_ENDPOINT=vcap.me:4004 " \
      "SWITCHBOARD_PORT=7345 " \
      "#{Peas.root}cli/bin/peas-dev"
  end

  # Normal popen shell
  def run(cmd, timeout = 60)
    Peas.sh "#{base_cmd} #{cmd}", timeout
  end

  # Backticks provide a TTY, useful for testing commands that use STDIN.raw
  def tty(cmd, timeout = 60)
    `#{base_cmd} #{cmd}`
  end

  # Skip the Peas CLI client, mostly for git pushing
  def sh(cmd)
    Peas.sh "cd #{@path} && GIT_SSH='#{Peas.root}/spec/integration/ssh_without_stricthostkeycheck.sh' #{cmd}"
  end
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec

  VCR.turned_off do
    WebMock.allow_net_connect!
    if Docker.version['Version'] != Peas::DOCKER_VERSION
      raise "Installed Docker version #{Docker.version['Version']}" \
        " does not match Peas' Docker version #{Peas::DOCKER_VERSION}"
    end
  end

  # Create the Peas container against which the CLI client will interact
  config.before(:all, :integration) do
    WebMock.allow_net_connect!
    VCR.turn_off!
    setup_data_volume
    @peas_container_id = Peas.sh(
      "docker run -d \
        --privileged \
        -i \
        --name peas-test \
        --volumes-from peas-data-test \
        -v #{Peas.root}:/home/peas/repo \
        -p 4004:4000 \
        -p 2223:22 \
        -p 7345:9345 \
        -e PEAS_ENV=production \
        -e GIT_PORT=2223 \
        tombh/peas"
    )
    # Whatever user is running these tests, copy their public key to the fake home directory for uploading by the client
    Peas.sh "mkdir -p #{TMP_PATH}/.ssh"
    Peas.sh "cp -f ~/.ssh/id_rsa.pub #{TMP_PATH}/.ssh"
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
    Peas.sh "rm -rf #{REPO_PATH}"
    Peas.sh "cd #{TMP_PATH} && git clone https://github.com/tombh/node-js-sample.git"

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
    Peas.sh "docker logs #{@peas_container_id} > #{TMP_PATH}/integration-tests.log 2>&1"
    # Remove the Peas test container. But the data container 'peas-data-test' still remains
    Peas.sh "docker stop #{@peas_container_id}"
    Peas.sh "docker rm -f #{@peas_container_id}"
    puts ""
    puts "Integration tests log available at #{TMP_PATH}/integration-tests.log"
    WebMock.disable_net_connect!
    VCR.turn_on!
  end
end
