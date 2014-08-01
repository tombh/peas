module Peas
  class AppMethods < Grape::API; end
  class API < Grape::API
    format :json

    helpers do
      # Convenience method to find and load the specified Peas app
      def load_app
        App.find_by(first_sha: params[:first_sha])
      rescue Mongoid::Errors::DocumentNotFound
        error! "App does not exist", 404
      end
    end

    resource :app do
      desc "List all apps"
      get do
        respond App.all.map { |a| a.name }
      end

      # /app/:first_sha
      route_param :first_sha do
        mount AppMethods
      end
    end
  end
end
