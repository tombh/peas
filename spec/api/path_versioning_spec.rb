require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  it "vendored path" do
    get "/api/vendor"
    last_response.body.should == { path: "Peas" }.to_json
  end

end
