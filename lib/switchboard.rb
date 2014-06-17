require 'socket'

module Peas
  class Switchboard
    def self.connection
      TCPSocket.new Peas.host, Peas::SWITCHBOARD_PORT
    end

    def self.wait_for_connection
      Timeout.timeout(2) do
        loop do
          begin
            s = connection
            s.close
            break
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            sleep 0.1
          end
        end
      end
    rescue Timeout::Error
      raise (
        "Couldn't connect to the Peas Switchboard at #{Peas.host}:#{Peas::SWITCHBOARD_PORT}"
      )
    end

    # Figure out if we're running inside a docker container. Used by pods to identify themselves to the controller.
    # Note that pods are docker-in-docker containers, they run app docker containers inside a host docker container.
    # Yo dawg I heard you like docker containers, and all that.
    def self.current_docker_host_id
      cgroups = File.open('/proc/self/cgroup').read
      matches = cgroups.match(/docker\/([a-z0-9]*)$/)
      if matches
        matches.captures.first
      else
        false
      end
    end

  end
end