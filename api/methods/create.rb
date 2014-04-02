module Peas
  class API < Grape::API
    desc "Create an app"
    post '/create' do
      App.create!({name: params[:name]})
    end
  end
end
