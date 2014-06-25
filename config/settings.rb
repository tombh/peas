module Peas
  # Synchronise API version with CLI version (controversial. may need to revisit this decision)
  VERSION = File.read File.expand_path("../../cli/VERSION", __FILE__)

  # The most recent version of Docker against which Peas has been tested
  DOCKER_VERSION = '0.11.1'

  # Location of Docker socket, used by Remote API
  DOCKER_SOCKET = 'unix:///var/run/docker.sock'

  # Peas base path for temp files
  TMP_BASE = '/tmp/peas'

  # Path to clone and pull repos for deploying
  TMP_REPOS = "#{TMP_BASE}/repos"

  # Path to tar repos into before sending to buildstep
  TMP_TARS = "#{TMP_BASE}/tars"

  # See self.domain() for more info
  # 'vcap.me' is managed by Cloud Foundry and has wildcard resolution to 127.0.0.1
  DEFAULT_CONTROLLER_DOMAIN = ENV['PEAS_HOST'] || 'vcap.me'

  # Port 4000 is just the default port used by Puma (the HTTP server) in a development environment
  DEFAULT_API_PORT = 4000

  # Port on which the messaging server runs
  SWITCHBOARD_PORT = 9345

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
    setting = Setting.where(key: 'domain')
    if setting.count == 1
      domain = setting.first.value
    else
      # Default
      domain = "#{DEFAULT_CONTROLLER_DOMAIN}:#{DEFAULT_API_PORT}"
    end
    # Make sure the domain always has a protocol at the beginning
    unless domain[/\Ahttp:\/\//] || domain[/\Ahttps:\/\//]
      domain = "http://#{domain}"
    else
      domain
    end
  end

  # Returns only the host part of the Peas domain. Eg; 'vcap' from http://vcap.me:4000
  def self.host
    URI.parse(Peas.domain).host
  end

  def self.switchboard_server_uri
    "#{Peas.host}:#{SWITCHBOARD_PORT}"
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
      # There is no host container when running in development
      'dockerless_pod'
    end
  end

  # Is this instance of Peas functioning as a controller?
  # Unless otherwise stated, Peas will function in a standalone state of being both the controller and a pod.
  def self.is_controller?
    ENV['PEAS_CONTROLLER'] ||= 'true'
  end

  # Is this instance of Peas functioning as a pod?
  def self.is_pod?
    ENV['PEAS_POD'] ||= 'true'
  end

end
