require 'spec_helper'

describe "Grape on RACK", js: true, type: :feature do
  context "homepage" do
    it "displays index.html page" do
      visit "/"
      title.should == "Rack Powers Web APIs"
    end
    context "ring" do
      before :each do
        @rang = Peas::PostPut.rang
        visit "/"
      end
      it "increments the ring counter" do
        find("#ring_value").should have_content "rang #{@rang + 1} time(s)"
        find("#ring_action").should have_content "click here to ring again"
        3.times do |i|
          find("#ring_action").click
          find("#ring_value").should have_content "rang #{@rang + i + 2} time(s)"
        end
      end
    end
  end
  context "page that doesn't exist" do
    before :each do
      visit "/invalid"
    end
    it "displays 404 page" do
      title.should == "Page Not Found"
    end
  end
  context "exception" do
    before :each do
      visit "/api/raise"
    end
    it "displays 500 page" do
      title.should == "Unexpected Error"
    end
  end
  context "curl" do
    it "reticulates a spline" do
      visit "/"
      url = "http://localhost:#{Capybara.server_port}/api/spline"
      json = '{"reticulated":"false"}'
      rc = `curl -X POST -d '#{json}' #{url} -H 'Accept: application/json' -H 'Content-Type:application/json' -s`
      rc.should == json
    end
  end
end
