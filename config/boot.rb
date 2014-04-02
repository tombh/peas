require 'rubygems'
require 'bundler/setup'
require 'mongoid'
require 'sidekiq'
require 'sidekiq-status'

Bundler.require :default, ENV['RACK_ENV']

Dir["#{File.dirname(__FILE__)}/../api/**/*.rb"].each { |f| require f }

Mongoid.load!(Peas.root + '/config/mongoid.yml')

module Peas
  class Application < Grape::API

    helpers do
      def logger
        Application.logger
      end
    end

    rescue_from :all do |e|
      Application.logger.error e
      if ENV['RACK_ENV'] = 'development'
        error_response({ message: "#{e.message} @ #{e.backtrace[0]}" })
      end
    end

    format :json
    mount ::Peas::API
    add_swagger_documentation api_version: 'v1'
  end
end
