module Peas
  class Application < Grape::API

    def intialize
      super
      version_check
    end

    helpers do
      def logger
        if Peas.environment != 'test'
          Application.logger
        else
          Logger.new("/dev/null")
        end
      end
    end

    rescue_from :all do |e|
      Application.logger.error e
      if Peas.environment == 'development'
        error_response({ message: "#{e.message} @ #{e.backtrace[0]}" })
      end
    end

    format :json
    mount ::Peas::API
    add_swagger_documentation api_version: 'v1'

    # Issue a warning if the host's version of Docker is newer than the version Peas is tested
    # against.
    # NB: I am currently unclear as to the relationship between the Docker Remote API version and
    # the Docker binary version, so for now I will assume that pinning against the binary version
    # also follows any breaking changes to the Docker Remote API.
    def self.docker_version_check
      if Gem::Version.new(Docker.version['Version']) > Gem::Version.new(Peas::DOCKER_VERSION)
        Application.logger.warn "Using version #{Docker.version['Version']} of Docker " +
          'which is newer than the latest version Peas has been tested with ' +
          "(#{Peas::DOCKER_VERSION})"
      end
    end
  end
end
