module Peas
  class AppMethods < Grape::API
    desc "Scale an app"
    put :scale do
      get_app
      scaling_hash = JSON.parse params[:scaling_hash]
      { job: @app.worker(:scale, scaling_hash) }
    end
  end
end
