#!/usr/bin/env ruby

# The Gardener is responsible for various long-running daemon-style tasks. Listening for worker
# jobs, capturing and archiving logs, sending monitoring reports and so on. It's boss is the
# Switchboard server.

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')
require 'celluloid/io'
require 'config/boot'

Dir["#{Peas.root}/switchboard/clients/**/*.rb"].each { |f| require f }

Peas::Switchboard.wait_for_connection

clients = [
  { client: LogsArchiver },
  Peas.controller? ? { client: WorkerReceiver, args: 'controller' } : {},
  Peas.pod? ? { client: WorkerReceiver, args: "#{Peas::POD_HOST}_pod" } : {}
]
running = []

# We don't want to use a Celluloid::SupervisionGroup as each client Actor is independent and needs
# to be able to crash and restart independent of the others.
clients.each do |client|
  next unless client.key? :client
  running << client[:client].supervise(*client[:args])
end

# Not sure how relevant the termination is for blocking threads, actors just seem to not respond
# and you get the 'Couldn't cleanly terminate all actors in 10 seconds!' error message.
trap('INT') do
  running.each(&:terminate)
  exit
end

sleep # Celluloid thing. Stops the main thread from finishing and allows child threads to continue.
