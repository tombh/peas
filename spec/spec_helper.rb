require 'rubygems'

ENV["RACK_ENV"] ||= 'test'

require File.expand_path("../../config/boot", __FILE__)
require 'rack/test'
require 'sidekiq/testing'

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec

  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
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

# Run an example against multiple versions of a faked Docker API.
# Usage: `it 'should do things', :docker {}`
# To add a new version add the version number as a new folder under spec/fixtures/docker_api and
# VCR will detect that no recordings have been made yet and so automatically create them.
# NB. When setting up examples, be sure to not to put setup code that interacts with Docker in
# 'before' blocks as this filter hook will not catch those calls and therefore will not be able to
# version them.
RSpec.configure do |config|
  config.around(:each, :docker) do |example|
    Dir["#{Peas.root}#{DOCKER_API_FIXTURES_BASE}/*"].each do |folder|
      version = folder.split('/').last
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
