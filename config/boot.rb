ENV['RACK_ENV'] ||= "test"

require 'rubygems'
require 'bundler/setup'

Bundler.require :default, ENV['RACK_ENV']

require './config/peas'

Dir["#{Peas.root}/lib/**/*.rb"].each { |f| require f }
Dir["#{Peas.root}/api/**/*.rb"].each { |f| require f }

Mongoid.load!(Peas.root + '/config/mongoid.yml')

# Add the Peas project path to Ruby's library path for easy require()'ing
$LOAD_PATH.unshift(Peas.root)

require 'config/peas_application'
