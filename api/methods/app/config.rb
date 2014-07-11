module Peas
  class AppMethods < Grape::API
    resource :config do
      desc 'Create and update app environment variables'
      params do
        requires :vars, type: String, desc: 'Config vars'
      end
      put do
        app = get_app
        vars = JSON.parse params[:vars]
        # Merge the new vars with a hashed version of the existing config
        new_config = app.config_hash.merge! vars
        # Convert the new config hash into an array
        app.config = new_config.map { |key, value| { key => value } }
        app.save!
        app.restart
        respond app.config
      end

      # Remove environment variables
      desc "Delete environment variables for an app"
      params do
        requires :keys, type: String, desc: 'Config vars'
      end
      delete do
        app = get_app
        # The CLI sends a list of keys to delete
        keys = JSON.parse params[:keys]
        new_config = []
        app.config_hash.each do |key, value|
          # Only reinsert the key if it's not marked for deletion
          new_config << { key => value } unless key.in? keys
        end
        app.config = new_config
        app.save!
        app.restart
        respond app.config
      end

      desc "Return all of the app's custom environment variables"
      get do
        app = get_app
        respond app.config
      end
    end
  end
end
