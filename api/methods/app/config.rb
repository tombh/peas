module Peas
  class AppMethods < Grape::API
    resource :config do
      desc 'Create and update app environment variables'
      params do
        requires :vars, type: String, desc: 'Config vars'
      end
      put do
        vars = JSON.parse params[:vars]
        load_app.config_update vars
        respond load_app.config
      end

      # Remove environment variables
      desc "Delete environment variables for an app"
      params do
        requires :keys, type: String, desc: 'Config vars'
      end
      delete do
        # The CLI sends a list of keys to delete
        keys = JSON.parse params[:keys]
        load_app.config_delete keys
        respond load_app.config
      end

      desc "Return all of the app's custom environment variables"
      get do
        respond load_app.config
      end
    end
  end
end
