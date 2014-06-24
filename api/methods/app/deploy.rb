module Peas
  class AppMethods < Grape::API
    desc "Deploy an app"
    get :deploy do
      app = get_app
      respond app.worker.deploy, :job
    end
  end
end
