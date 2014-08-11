ENV["RACK_ENV"] = ENV["PEAS_ENV"] = 'test'

require File.expand_path("../../config/boot", __FILE__)
Bundler.require :test
require 'rack/test'
require 'webmock/rspec'
require 'celluloid/test'
require 'docker_creation_mock.rb'

ENV['PEAS_API_LISTENING'] = 'true'

TMP_BASE = '/tmp/peas/test'

# Note: I've found that the ordering for the config hooks is important. Specifically that Mongoid's
# session needs to be dropped before shutting down Celluloid. Specifying hooks first seems to mean
# they are run last.
RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec
  config.filter_run_excluding :integration, :service

  config.before(:suite) do
    Mongoid.default_session.drop
  end

  config.before(:each, :celluloid) do
    Celluloid.boot
  end

  config.after(:each, :celluloid) do
    Celluloid.shutdown_timeout = 0.02
    Celluloid.shutdown
  end

  config.before(:each, :mock_worker) do
    @mock_worker = double
    expect(Peas::ModelWorker::ModelProxy).to receive(:new).and_return(@mock_worker)
  end

  config.before(:each) do
    allow(Docker).to receive(:version).and_return('Version' => Peas::DOCKER_VERSION)
    Pod.destroy_all
    Pod.create_stub
    Pod.create_stub
  end

  config.after(:each) do
    Mongoid.default_session.drop
  end

  config.before(:each, :with_worker) do
    Celluloid.boot
    stub_const('Peas::SWITCHBOARD_HOST', SWITCHBOARD_TEST_HOST)
    stub_const('Peas::SWITCHBOARD_PORT', SWITCHBOARD_TEST_PORT)
    allow(Peas).to receive(:host).and_return(SWITCHBOARD_TEST_HOST)
    @server = switchboard_server
    @controller_worker = WorkerReceiver.new 'controller'
    @pod_worker = WorkerReceiver.new Pod.first.to_s
  end

  config.after(:each, :with_worker) do
    @server.terminate
    Celluloid::Actor.clear_registry
    Celluloid.shutdown_timeout = 0.02
    Celluloid.shutdown
  end
end

# VCR is used to record HTTP interactions and replay them. Currently used to fake a Docker
# environment
DOCKER_API_FIXTURES_BASE = 'spec/fixtures/docker_api'

VCR.configure do |c|
  c.hook_into :excon
  c.default_cassette_options = { record: :new_episodes }
end

# Run an example against multiple versions of a mocked Docker API.
# Usage: `it 'should do things', :docker {}`
# To add a new version add the version number as a new folder under spec/fixtures/docker_api and
# VCR will detect that no recordings have been made yet and so automatically create them.
# NB. When setting up examples, be sure to not put setup code that interacts with Docker in
# 'before' blocks as this filter below will not catch those calls and therefore will not be able to
# version them.
RSpec.configure do |config|
  config.around(:each, :docker) do |example|
    # Loop over each folder version
    Dir["#{Peas.root}#{DOCKER_API_FIXTURES_BASE}/*"].each do |folder|
      version = folder.split('/').last
      # Just a little safety measure. Just in case you create an empty folder for fixtures against
      # a new Docker version and you accidently mismatch the versions.
      if Dir["#{folder}/*"].empty?
        VCR.turned_off do
          @docker_version = Docker.version['Version']
        end
        if version != @docker_version
          puts "WARNING: Preventing the creation of fixtures for Docker #{@docker_version} in a " \
            "folder labelled #{version}"
          next
        end
      end
      # Change the fixtures path depending on the current current folder version
      VCR.configure do |c|
        c.cassette_library_dir = DOCKER_API_FIXTURES_BASE + '/' + version
      end
      VCR.use_cassette(example.metadata[:description]) do
        # Append the Docker version otherwise each example will look the same
        example.metadata[:description] += " (Docker version: #{version})"
        example.run
      end
    end
  end
end

def list_mongo_dbs
  Moped::Session.new(['localhost:27017']).databases['databases'].map { |d| d['name'] }
end

# SWITCHBOARD

Dir["#{Peas.root}/switchboard/**/*.rb"].each { |f| require f }

SWITCHBOARD_TEST_HOST = '127.0.0.1'
SWITCHBOARD_TEST_PORT = 79345

Celluloid.logger = nil unless ENV['CELLULOID_LOGS']

def client_connection
  TCPSocket.new SWITCHBOARD_TEST_HOST, SWITCHBOARD_TEST_PORT
end

def switchboard_server
  SwitchboardServer.new(SWITCHBOARD_TEST_HOST, SWITCHBOARD_TEST_PORT)
end

# Creates a client and server into which you can inject a manipulated Connection instance for testing.
# Got the idea from celluloid/reel's spec_helper
def with_socket_pair
  server = TCPServer.new SWITCHBOARD_TEST_HOST, SWITCHBOARD_TEST_PORT
  client = client_connection
  peer = server.accept

  begin
    yield client, peer
  ensure
    server.close rescue nil
    client.close rescue nil
    peer.close   rescue nil
  end
end

# Some extra Switchboard commands specifically for use in testing
module Commands
  def fake; end

  def raise_exception
    raise
  end
end

# Make a non-bare repo to push to the bare repo (simulating a `git push peas`)
def create_non_bare_repo
  non_bare_path = "#{Peas::APP_REPOS_PATH}/non_bare_repo"
  FileUtils.mkdir_p non_bare_path
  Peas.pty "cd #{non_bare_path} && " \
    "git init && " \
    "touch lathyrus.odoratus && " \
    "git add . --all && " \
    "GIT_AUTHOR_NAME=test git commit -m'first commit'"
  non_bare_path
end
