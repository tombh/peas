require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  it "uploads a file" do
    image_filename = "spec/fixtures/grape_logo.png"
    post "/api/avatar", image_file: Rack::Test::UploadedFile.new(image_filename, 'image/png')
    last_response.status.should == 201
    last_response.body.should == {
      "filename" => "grape_logo.png",
      "size" => File.size(image_filename)
    }.to_json
  end

end
