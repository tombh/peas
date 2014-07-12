module Peas
  class AppMethods < Grape::API; end
  class API < Grape::API
    helpers do
      # Convenience method to find and load the specified Peas app
      def load_app
        App.find_by(first_sha: params[:first_sha])
      rescue Mongoid::Errors::DocumentNotFound
        error! "App does not exist", 404
      end
    end

    # /app/:first_sha
    resource :app do
      route_param :first_sha do
        mount AppMethods
      end
    end
  end
end
