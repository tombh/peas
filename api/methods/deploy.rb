module Peas
  class API < Grape::API
    desc "Deploy an app"
    get '/deploy' do
      Peas::Application.docker_version_check
      app = App.where(first_sha: params[:first_sha])
      error! "App does not exist", 404 if app.count == 0
      { job: app.first.worker(:deploy) }
    end
  end
end
