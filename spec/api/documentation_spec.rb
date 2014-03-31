require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  context "swagger documentation root" do
    before do
      get "/api/swagger_doc"
      last_response.status.should == 200
      @json = JSON.parse(last_response.body)
    end

    it "exposes api version" do
      @json["apiVersion"].should == "v1"
      @json["apis"].size.should == 1
    end
  end

  context "swagger documentation api" do
    before do
      get "/api/swagger_doc/api"
      last_response.status.should == 200
      @apis = JSON.parse(last_response.body)["apis"]
    end

    it "exposes entity documentation" do
      entities = @apis.detect { |api| api['path'] == '/api/entities/{id}.{format}' }
      operations = entities['operations']
      operations.size.should == 1
      parameters = Hash[operations.first['parameters'].map { |parameter| [parameter['name'], parameter['description']] }]
      parameters.should == {
        "id" => "",
        "length" => "length of the tool",
        "weight" => "weight of the tool",
        "foo" => "foo"
      }
    end
  end
end
