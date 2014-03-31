module Peas
  class PostPut < Grape::API
    class << self
      attr_accessor :rang
    end
    format :json
    desc "Returns pong."
    get :ring do
      { rang: PostPut.rang }
    end
    post :ring do
      result = (PostPut.rang += 1)
      { rang: result }
    end
    put :ring do
      error!("missing :count", 400) unless params[:count]
      result = (PostPut.rang += params[:count].to_i)
      { rang: result }
    end
  end
end

Peas::PostPut.rang = 0
