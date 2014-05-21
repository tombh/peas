require 'integration_helper'

describe 'The Peas PaaS Integration Tests', :integration do

  describe 'Settings' do
    it 'should update the domain' do
      response = cli 'settings --domain 127.0.0.1:4004'
      expect(response).to eq "New settings:\n{\n  \"domain\": \"http://127.0.0.1:4004\"\n}"
    end
  end

  describe 'Deploy' do
    before :each do
      # Create the app in Peas
      response = cli 'create', REPO_PATH
      expect(response).to eq "App 'node-js-sample' successfully created"
    end

    it 'should deploy a basic nodejs app' do
      response = cli 'deploy', REPO_PATH
      expect(response).to include '-----> Fetching https://github.com/heroku/node-js-sample'
      expect(response).to include '-----> Installing dependencies'
      expect(response).to include '-----> Discovering process types'
      expect(response).to include "-----> Scaling process 'web:1'"
      expect(response).to include "       Deployed to http://node-js-sample.vcap.me:4004"
      expect(response.lines.length).to be > 50
      # The app should be accessible
      sleep 2
      response = sh "curl -s node-js-sample.vcap.me:4004"
      expect(response).to eq 'Hello World!'
    end

    it 'should use a custom buildpack' do

    end
  end

  describe 'Config' do
    it 'should set config for an app' do
    end
  end
end
