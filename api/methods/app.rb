module Peas
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

    # /app
    resource :app do
      before do
        authenticate!
      end

      desc "List all apps"
      get do
        respond App.all.map(&:name)
      end

      desc "Create an app"
      params do
        optional :muse, type: String, desc: "A clue to help generate the app's name"
      end
      post do
        muse = params.fetch :muse, nil
        GitSSH.add_key params[:public_key] if Peas::DIND
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
        # DELETE /app/:name
        desc "Destroy an app"
        delete do
          app = load_app
          app.destroy
          respond "App '#{app.name}' successfully destroyed"
        end

        # /app/:name/config
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

        # PUT /app/:name/scale
        desc "Scale an app"
        params do
          requires :scaling_hash, desc: 'Scaling hash'
        end
        put :scale do
          scaling_hash = JSON.parse params[:scaling_hash]
          respond load_app.worker.scale(scaling_hash), :job
        end
      end
    end
  end
end
