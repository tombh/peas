module Peas
  class AppMethods < Grape::API
    resource :config do

      desc 'Create and update app environment variables'
      params do
        requires :vars, type: String, desc: 'Config vars'
      end
      put :config do
        get_app
        error! "No config values given", 400 if !params[:vars]
        vars = JSON.parse params[:vars]
        new_config = @app.config.merge vars
        @app.update_attributes!({config: new_config})
        @app.restart
        {message: @app.config}
      end

      # Remove environment variables
      desc "Delete environment variables for an app"
      params do
        requires :vars, type: String, desc: 'Config vars'
      end
      delete :config do
        get_app
        error! "No config values given", 400 if !params[:vars]
        # The CLI sends a list of keys to delete
        keys = JSON.parse params[:keys]
        @app.config.each do |key, value|
          # Only reinsert the key if it's not marked for deletion
          new_config << {key => value} if !key.in? keys
        end
        @app.config = new_config
        @app.save!
        @app.restart
        {message: @app.config}
      end

      desc "Return all of the app's custom environment variables"
      get :config do
        get_app
        {message: @app.config}
      end

    end
  end
end
