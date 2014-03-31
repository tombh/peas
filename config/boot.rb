require 'rubygems'
require 'bundler/setup'
require 'mongoid'
require 'sidekiq'

Bundler.require :default, ENV['RACK_ENV']

Dir["#{File.dirname(__FILE__)}/../api/**/*.rb"].each { |f| require f }

Mongoid.load!(Peas.root + '/config/mongoid.yml')

module Peas
  class API < Grape::API
    format :json
    mount ::Peas::Ping
    mount ::Peas::RescueFrom
    mount ::Peas::PathVersioning
    mount ::Peas::HeaderVersioning
    mount ::Peas::PostPut
    mount ::Peas::PostJson
    mount ::Peas::ContentType
    mount ::Peas::UploadFile
    mount ::Peas::Entities::API
    add_swagger_documentation api_version: 'v1'
  end
end

