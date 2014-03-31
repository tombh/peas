require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::App.instance
  end

  context "CORS" do
    it "supports options" do
      options "/", {},
              "HTTP_ORIGIN" => "http://cors.example.com",
              "HTTP_ACCESS_CONTROL_REQUEST_HEADERS" => "Origin, Accept, Content-Type",
              "HTTP_ACCESS_CONTROL_REQUEST_METHOD" => "GET"

      last_response.status.should == 200
      last_response.headers['Access-Control-Allow-Origin'].should == "http://cors.example.com"
      last_response.headers['Access-Control-Expose-Headers'].should == ""
    end
    it "includes Access-Control-Allow-Origin in the response" do
      get "/api/ping", {}, "HTTP_ORIGIN" => "http://cors.example.com"
      last_response.status.should == 200
      last_response.headers['Access-Control-Allow-Origin'].should == "http://cors.example.com"
    end
    it "includes Access-Control-Allow-Origin in errors" do
      get "/invalid", {}, "HTTP_ORIGIN" => "http://cors.example.com"
      last_response.status.should == 404
      last_response.headers['Access-Control-Allow-Origin'].should == "http://cors.example.com"
    end
  end

end
