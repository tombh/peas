module Peas
  class AppMethods < Grape::API
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
