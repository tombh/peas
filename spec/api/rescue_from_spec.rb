require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  it "rescues all exceptions" do
    get "/api/raise"
    last_response.status.should == 500
    last_response.body.should == "Unexpected error."
  end

end
