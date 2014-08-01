Dir["#{Peas.root}/api/methods/**/*.rb"].each { |f| require f }

module Peas
  class API < Grape::API
    version 'v1', using: :header, vendor: 'peas'
    format :json
    add_swagger_documentation api_version: 'v1'

    before do
      docker_version_check
    end

    helpers do
      def logger
        if Peas.environment == 'test'
          Logger.new("/dev/null")
        else
          API.logger
        end
      end

      # Issue a warning if the host's version of Docker is newer than the version Peas is tested
      # against.
      # NB: I am currently unclear as to the relationship between the Docker Remote API version and
      # the Docker binary version, so for now I will assume that pinning against the binary version
      # also follows any breaking changes to the Docker Remote API.
      def docker_version_check
        return if Gem::Version.new(Peas::DOCKER_VERSION) >= Gem::Version.new(Docker.version['Version'])
        API.logger.warn "Using version #{Docker.version['Version']} of Docker " \
          'which is newer than the latest version Peas has been tested with ' \
          "(#{Peas::DOCKER_VERSION})"
      end

      def respond(response, key = :message)
        {
          version: Peas::VERSION,
          key => response
        }
      end
    end

    rescue_from :all do |e|
      API.logger.error e
      if Peas.environment == 'development'
        error_response(message: "#{e.message} @ #{e.backtrace[0]}")
      end
    end if Peas.environment != 'test'

    # Make sure all paths are loaded before the catch-all 404 block
    mount Peas::AdminMethods
    mount Peas::AppMethods

    route :any, '/' do
      respond(
        "This is the Peas API for #{Peas.domain}. See https://github.com/tombh/peas for more details"
      )
    end

    route :any, '*path' do
      error!("404, you've been led up the garden path", 404)
    end

  end
end
