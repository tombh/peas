module Peas
  # Synchronise API version with CLI version (controversial. may need to revisit this decision)
  VERSION = File.read File.expand_path("../../cli/VERSION", __FILE__)

  # The most recent version of Docker against which Peas has been tested
  DOCKER_VERSION = '0.9.0'

  # Root path of the project on the host filesystem
  def self.root
    File.join(File.dirname(__FILE__), "../")
  end

  # Environment, normally one of: 'production', 'development', 'test'
  def self.environment
    ENV['RACK_ENV']
  end

  # The FQDN upon which the API resides and through which apps can be accessed via subdomains.
  # Eg; peas.com is the location of the API and an app called 'hipster' is accessible via
  # 'hipster.peas.com'
  def self.domain
    setting = Setting.where(key: 'domain')
    if setting.count == 1
      setting.first.value
    else
      # Default.
      # 'vcap.me' is managed by Cloud Foundry and has wildcard resolution to 127.0.0.1
      'vcap.me:4000'
    end
  end
end
