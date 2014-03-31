require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  context "header based versioning" do
    it "vendored header" do
      get "/api", nil,  "HTTP_ACCEPT" => "application/vnd.Peas-v1+json"
      last_response.status.should == 200
      last_response.body.should == { header: "Peas" }.to_json
    end
    it "invalid version" do
      get "/api", nil,  "HTTP_ACCEPT" => "application/vnd.Peas-v2+json"
      last_response.status.should == 404
    end
  end

end
