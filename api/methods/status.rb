module Peas
  class API < Grape::API
    desc "Get the status of a job"
    get '/status' do
      Sidekiq::Status::get_all params[:job]
    end
  end
end
