module Peas
  class API < Grape::API
    desc "Create an app"
    post '/create' do
      Peas::Application.docker_version_check
      name = App.remote_to_name params[:remote]
      App.create!({
        first_sha: params[:first_sha],
        remote: params[:remote],
        name: name
      })
      {message: "App '#{name}' successfully created"}
    end
  end
end
