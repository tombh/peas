require 'rubygems'

ENV["RACK_ENV"] ||= 'test'

require File.expand_path("../../config/boot", __FILE__)
require 'rack/test'
require 'sidekiq/testing'
require 'docker_creation_mock.rb'

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec

  config.before(:suite) do
    Mongoid.default_session.drop
  end

  config.before(:each) do
    allow(Docker).to receive(:version).and_return({'Version' => Peas::DOCKER_VERSION})
  end

  config.after(:each) do
    Mongoid.default_session.drop
  end
end

RSpec::Sidekiq.configure do |config|
  config.warn_when_jobs_not_processed_by_sidekiq = false
end

# VCR is used to record HTTP interactions and replay them. Currently used to fake a Docker
# environment
DOCKER_API_FIXTURES_BASE = 'spec/fixtures/docker_api'

VCR.configure do |c|
  c.hook_into :excon
  c.default_cassette_options = { :record => :new_episodes }
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
          puts "WARNING: Preventing the creation of fixtures for Docker #{@docker_version} in a " +
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
