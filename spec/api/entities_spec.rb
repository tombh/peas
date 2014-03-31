require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  it "returns exposed entity" do
    get "/api/entities/123"
    last_response.status.should == 200
    JSON.parse(last_response.body).should eq(
      "tool" => {
        "id" => "123",
        "length" => 10,
        "weight" => "20kg"
      }
    )
  end

  it "returns exposed entity with options" do
    get "/api/entities/123?foo=bar"
    last_response.status.should == 200
    JSON.parse(last_response.body).should eq(
      "tool" => {
        "id" => "123",
        "length" => 10,
        "weight" => "20kg",
        "foo" => "bar"
      }
    )
  end

  it "uses a custom formatter to reset xml root" do
    get "/api/entities/123.xml?foo=bar"
    last_response.status.should == 200
    last_response.body.should == <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<tool>
  <id>123</id>
  <length type="integer">10</length>
  <weight>20kg</weight>
  <foo>bar</foo>
</tool>
XML
  end

end
