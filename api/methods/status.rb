module Peas
  class API < Grape::API
    desc "Get the status of a job"
    params do
      requires :job, desc: 'Job ID'
    end
    get '/status' do
      Sidekiq::Status::get_all params[:job]
    end
  end
end
