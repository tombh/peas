module Peas
  module Services
    class ServicesBase

      def initialize(app)
        @app = app
      end

      # The type of service currently instantiated
      def type
        self.class.name.demodulize.downcase
      end

      # Get the admin connection URI for the service
      # Eg; 'postgresql://root:password@localhost:5432'
      def uri
        Setting.find_by(key: type).value
      end

      def uri_parsed
        URI.parse(uri)
      end

      def host_with_port
        "#{uri_parsed.host}:#{uri_parsed.port}"
      end

      def user_name
        @app.name
      end

      def instance_name
        @app.name
      end

      # Uses the Service-specific version of create() to create an Addon for an app
      def create_instance
        addon = {
          app: @app,
          type: type,
          uri: create
        }
        Addon.create addon
      end

      # Destroy the instance created above
      def destroy_instance
        destroy
        Addon.where(app: @app, type: type).first.destroy
      end

      # Every Service class must contain the following 2 methods...

      # Creates an instance of a service. Eg; an app-specific redis or postgres DB. Usually with its
      # own username and password. Should return the full URI to the service instance.
      def create; end

      # Destroys the instance created above
      def destroy; end
    end
  end
end
