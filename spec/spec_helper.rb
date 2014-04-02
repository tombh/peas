require 'rubygems'

ENV["RACK_ENV"] ||= 'test'

require File.expand_path("../../config/environment", __FILE__)
require 'rack/test'
require 'sidekiq/testing'
require 'fabrication'


RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec

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

require 'capybara/rspec'
Capybara.configure do |config|
  config.app = Peas::API.new
  config.server_port = 9293
end
