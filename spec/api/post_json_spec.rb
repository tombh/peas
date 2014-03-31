require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  [true, false].each do |reticulated|
    it "POST #{reticulated ? 'reticulated' : 'unreticulated' } spline" do
      post '/api/spline', 'reticulated' => reticulated
      last_response.status.should == 201
      JSON.parse(last_response.body).should == { 'reticulated' => reticulated.to_s }
    end
  end

end
