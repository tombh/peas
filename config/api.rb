module Peas
  class API < Grape::API
    version 'v1', using: :header, vendor: 'peas'
    format :json
    add_swagger_documentation api_version: 'v1'

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
        if Gem::Version.new(Docker.version['Version']) > Gem::Version.new(Peas::DOCKER_VERSION)
          API.logger.warn "Using version #{Docker.version['Version']} of Docker " +
            'which is newer than the latest version Peas has been tested with ' +
            "(#{Peas::DOCKER_VERSION})"
        end
      end

      # Convenience method to find and load the specified Peas app
      def get_app
        begin
          @app = App.find_by(first_sha: params[:first_sha])
        rescue Mongoid::Errors::DocumentNotFound
          error! "App does not exist", 404 if !@app
        end
      end
    end

    rescue_from :all do |e|
      API.logger.error e
      if Peas.environment == 'development'
        error_response({ message: "#{e.message} @ #{e.backtrace[0]}" })
      end
    end if Peas.environment != 'test'

    before do
      docker_version_check
    end

    params do
      requires :first_sha, type: String
    end
    resource :app do
      mount AppMethods
    end

  end
end
