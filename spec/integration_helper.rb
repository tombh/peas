require 'rubygems'
require 'timeout'
require_relative '../config/settings'

TMP_PATH = '/tmp/peas'
FileUtils.mkdir_p TMP_PATH

# Simple convenience wrapper for the command line
def sh cmd
  output = `#{cmd} 2>&1`.strip
  if $?.to_i == 0
    return output
  else
    raise "`#{cmd}` failed with: \n--- \n #{output} \n---"
  end
end

# Helper to call Peas CLI
def cli cmd, path = '.'
  sh "cd #{path} && PEAS_API_ENDPOINT=localhost:4004 #{Peas.root}/cli/bin/peas-dev #{cmd}"
end

# Find the test-specific data volume
def get_data_vol_id
  output = sh "docker ps -a | grep 'busybox:latest.*peas-data-test' | awk '{print $1}'"
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
  sh "docker run -v /var/lib/docker -v /data/db --name peas-data-test busybox true"
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
  # Close the connection
  def close
    @io.close
  end
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec
  config.treat_symbols_as_metadata_keys_with_true_values = true

  # Create the Peas container against which the CLI client will interact
  config.before(:all, :integration) do
    setup_data_volume
    @peas_container_id = sh(
      "docker run -d \
        --privileged \
        -i \
        --name peas-test \
        --volumes-from peas-data-test \
        -v #{Peas.root}:/home/peas \
        -p 4004:4000 \
        -e RACK_ENV=production \
        tombh/peas"
    )
    # Wait until the container has completely booted
    Timeout::timeout(15*60) do
      result = `bash -c 'until [ "$(curl -s localhost:4004)" == "Not Found" ]; do sleep 1; done' 2>&1`
      raise result if $?.to_i != 0
    end
    # Open an IO pipe to the launched container
    @peas_io = ContainerConnection.new @peas_container_id
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
  end

  # Reset state after each spec
  config.after(:each, :integration) do
    # TODO: need a way to check if these commands were successful
    @peas_io.bash "mongo peas --eval 'db.dropDatabase();'"
    @peas_io.bash "redis-cli FLUSHALL"
    @peas_io.bash "docker kill `docker ps -a -q` && docker rm `docker ps -a -q`"
  end
end

