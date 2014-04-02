require 'rubygems'

ENV["RACK_ENV"] ||= 'test'

require File.expand_path("../../config/environment", __FILE__)
require 'rack/test'
require 'sidekiq/testing'


RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :rspec
end

require 'capybara/rspec'
Capybara.configure do |config|
  config.app = Peas::API.new
  config.server_port = 9293
end
