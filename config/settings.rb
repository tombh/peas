module Peas
  # Synchronise API version with CLI version (controversial. may need to revisit this decision)
  VERSION = File.read File.expand_path("../../cli/VERSION", __FILE__)

  # The most recent version of Docker against which Peas has been tested
  DOCKER_VERSION = '1.1.1'

  # Location of Docker socket, used by Remote API
  DOCKER_SOCKET = 'unix:///var/run/docker.sock'

  # Figure out if we're running inside a docker container.
  DIND = begin
    cgroups = File.open('/proc/self/cgroup').read
    matches = cgroups.match(/docker-([a-z0-9]*)$/)
    if matches
      # Return the Docker ID. Note that this changes every time the DinD container boots
      matches.captures.first
    else
      false
    end
  end

  GIT_USER = Peas::DIND ? 'git' : 'peas'

  # Peas base path for temp files
  TMP_BASE = '/tmp/peas'

  # Path to tar repos into before sending to buildstep
  TMP_TARS = "#{TMP_BASE}/tars"

  # Path to receive repos for deploying
  APP_REPOS_PATH = DIND ? "/home/git" : "#{TMP_BASE}/repos"

  # See self.domain() for more info
  # 'vcap.me' is managed by Cloud Foundry and has wildcard resolution to 127.0.0.1
  DEFAULT_CONTROLLER_DOMAIN = ENV['PEAS_HOST'] || 'vcap.me'

  # Port 4000 is just the default port used by Puma (the HTTP server) in a development environment
  DEFAULT_API_PORT = 4000

  # Port on which the messaging server runs
  SWITCHBOARD_PORT = ENV['SWITCHBOARD_PORT'] || 9345

  # Root path of the project on the host filesystem
  def self.root
    File.join(File.dirname(__FILE__), "../")
  end

  # Environment, normally one of: 'production', 'development', 'test'
  def self.environment
    ENV['PEAS_ENV']
  end

  # Used for lots of things.
  # 1) REST API
  # 2) SWITCHBOARD
  # 3) MongoDB (so pods can also access the DB)
  # 4) By builder to create the FQDN for an app; eg http://mycoolapp.peasserver.com
  # Note that only 4) is effected by changing the :domain key in the Setting model
  def self.domain
    domain = Setting.retrieve 'peas.domain'
    # Make sure the domain always has a protocol at the beginning
    unless domain[/\Ahttp:\/\//] || domain[/\Ahttps:\/\//]
      domain = "http://#{domain}"
    else
      domain
    end
  end

  # Returns only the host part of the Peas domain. Eg; 'vcap.me' from http://vcap.me:4000
  def self.host
    URI.parse(Peas.domain).host
  end

  def self.switchboard_server_uri
    "#{Peas.host}:#{SWITCHBOARD_PORT}"
  end

  # Is this instance of Peas functioning as a controller?
  # Unless otherwise stated, Peas will function in a standalone state of being both the controller and a pod.
  def self.controller?
    ENV['PEAS_CONTROLLER'] ||= 'true'
  end

  # Is this instance of Peas functioning as a pod?
  def self.pod?
    ENV['PEAS_POD'] ||= 'true'
  end

  # The publicly accessible address for the pod. Only relevant if we're running as a pod of course
  def self.pod_host
    ENV['DIND_HOST'] || 'localhost'
  end

  # Introspect the lib/services folder to find the available classes that allow the management
  # of services like redis, memcached, etc
  def self.available_services
    Peas::Services.constants.select { |c|
      constant = Peas::Services.const_get(c)
      constant.is_a?(Class) && constant != Peas::Services::ServicesBase
    }.map { |s|
      s.to_s.downcase
    }
  end

  # Available services that also have an admin connection URI set
  def self.enabled_services
    Peas.available_services.select { |service|
      Setting.where(key: "#{service}.uri").count == 1
    }
  end

  def self.logger
    output = Peas.environment == 'test' ? '/dev/null' : STDOUT
    @logger ||= Logger.new output
  end
end
