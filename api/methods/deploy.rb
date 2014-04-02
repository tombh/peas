module Peas
  class API < Grape::API
    desc "Deploy an app"
    get '/deploy' do
      error! "App does not exist" if App.where(first_sha: params[:first_sha]).count == 0
      { job: DeployWorker.perform_async(params[:first_sha]) }
    end
  end
end
