module Peas
  class API < Grape::API
    desc "Deploy an app"
    get '/deploy' do
      { job: DeployWorker.perform_async(params[:name]) }
    end
  end
end
