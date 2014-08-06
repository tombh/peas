module Peas
  class AppMethods < Grape::API; end
  class API < Grape::API
    format :json

    helpers do
      # Convenience method to find and load the specified Peas app
      def load_app
        App.find_by(name: params[:name])
      rescue Mongoid::Errors::DocumentNotFound
        error! "App does not exist", 404
      end
    end

    resource :app do
      desc "List all apps"
      get do
        respond App.all.map { |a| a.name }
      end

      desc "Create an app"
      post do
        muse = params.fetch :muse, nil
        app = App.create!(
          name: App.divine_name(muse)
        )
        respond(
          "App '#{app.name}' successfully created", :message,
          remote_uri: app.remote_uri
        )
      end

      # /app/:name
      route_param :name do
        mount AppMethods
      end
    end
  end
end
