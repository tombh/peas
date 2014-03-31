module Peas
  class Ping < Grape::API
    get '/ping' do
      { ping: "pong" }
    end
  end
end
