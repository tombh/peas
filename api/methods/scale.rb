module Peas
  class API < Grape::API
    desc "Scale an app"
    put '/scale' do
    	Peas::Application.docker_version_check
      app = App.where(first_sha: params[:first_sha])
      error! "App does not exist", 404 if app.count == 0
      scaling_hash = JSON.parse params[:scaling_hash]
      { job: app.first.worker(:scale, scaling_hash) }
    end
  end
end
