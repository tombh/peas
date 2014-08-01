# Requiring this file loads everything you need to run Peas.
# Note that Peas can run in two separate roles; controller or pod.
#
# CONTROLLER
# The central mothership. There is only one (maybe oneday there will be more, because someone starts using Peas on
# on such a large scale the contoller needs to be load-balanced). It runs the API and the Switchboard messsaging server.
#
# POD
# There can be lots of pods. All they really do is run docker containers for apps, most often these will be web
# processes, but they might also be one-off consoles, worker processes, etc.

ENV['PEAS_ENV'] ||= 'development'
ENV['RACK_ENV'] = ENV['PEAS_ENV']

require 'rubygems'
require 'bundler/setup'

Bundler.require :default, ENV['PEAS_ENV']

I18n.enforce_available_locales = false

require_relative './settings'

Mongoid.load!(Peas.root + '/config/mongoid.yml')

# Add the Peas project path to Ruby's library path for easy require()'ing
$LOAD_PATH.unshift(Peas.root)

require 'config/api'

Dir["#{Peas.root}/lib/**/*.rb"].each { |f| require f }
# The /api folder is loaded regardless of role (controller/pod). The api/methods may not be needed to run a pod, but
# there seems little advantage in explictly preventing their loading for pods. Memory savings would be trivial.
Dir["#{Peas.root}/api/**/*.rb"].each { |f| require f }

# Create a pod stub if this a default combined controller-pod setup
Pod.create_stub
