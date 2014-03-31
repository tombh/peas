require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  it "creates an app" do
    post "/create", {name: 'test-app'}
    expect(last_response.status).to eq 201
    expect(JSON.parse(last_response.body)).to include({'name' => 'test-app'})
  end

end
