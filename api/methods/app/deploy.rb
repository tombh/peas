module Peas
  class AppMethods < Grape::API
    desc "Deploy an app"
    get :deploy do
      respond load_app.worker.deploy, :job
    end
  end
end
