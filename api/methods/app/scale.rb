module Peas
  class AppMethods < Grape::API
    desc "Scale an app"
    params do
      requires :scaling_hash, desc: 'Scaling hash'
    end
    put :scale do
      app = get_app
      scaling_hash = JSON.parse params[:scaling_hash]
      { job: app.worker(:scale, scaling_hash) }
    end
  end
end
