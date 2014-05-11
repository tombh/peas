ENV['RACK_ENV'] ||= "development"

require 'rubygems'
require 'bundler/setup'

Bundler.require :default, ENV['RACK_ENV']

require './config/settings'

Mongoid.load!(Peas.root + '/config/mongoid.yml')

# Add the Peas project path to Ruby's library path for easy require()'ing
$LOAD_PATH.unshift(Peas.root)

Dir["#{Peas.root}/lib/**/*.rb"].each { |f| require f }
Dir["#{Peas.root}/api/**/*.rb"].each { |f| require f }

require 'config/api'
