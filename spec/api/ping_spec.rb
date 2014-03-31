require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  it "ping" do
    get "/api/ping"
    last_response.status.should == 200
    last_response.body.should == { ping: "pong" }.to_json
  end

end
