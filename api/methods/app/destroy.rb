module Peas
  class AppMethods < Grape::API
    desc "Destroy an app"
    delete do
      app = load_app
      app.destroy
      respond "App '#{app.name}' successfully destroyed"
    end
  end
end
