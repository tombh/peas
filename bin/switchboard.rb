#!/usr/bin/env ruby

# The Switchboard server is the central hub for sending and receveing communications between the
# various components of Peas.

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')
require 'switchboard/server/lib/switchboard_server'

# The supervise method is like God or Monit. It keeps watch of the Celluloid actor and restarts it
# if it crashes.
supervisor = SwitchboardServer.supervise('0.0.0.0', Peas::SWITCHBOARD_PORT)
trap("INT") { supervisor.terminate; exit }

sleep # Celluloid thing. Stops the main thread from finishing and allows child thread to continue.
