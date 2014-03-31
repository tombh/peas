module Peas
  class UploadFile < Grape::API
    format :json
    desc "Upload an image."
    post "avatar" do
      {
        filename: params[:image_file][:filename],
        size: params[:image_file][:tempfile].size
      }
    end
  end
end
