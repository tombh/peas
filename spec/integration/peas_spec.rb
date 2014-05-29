require 'integration_helper'

describe 'The Peas PaaS Integration Tests', :integration do
  before :each do
    @cli = Cli.new REPO_PATH
  end

  describe 'Settings' do
    it 'should update the domain' do
      response = @cli.run 'settings --domain 127.0.0.1:4004'
      expect(response).to eq "New settings:\n{\n  \"domain\": \"http://127.0.0.1:4004\"\n}"
    end
  end

  context 'Apps' do
    before :each do
      # Create the app in Peas
      response = @cli.run 'create'
      expect(response).to eq "App 'node-js-sample' successfully created"
    end

    describe 'Deploy' do
      it 'should deploy a basic nodejs app' do
        response = @cli.run 'deploy'
        expect(response).to include '-----> Fetching https://github.com/tombh/node-js-sample.git'
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
        response = @cli.run 'config set FOO=BAR'
        expect(response).to eq '{"FOO"=>"BAR"}'
      end
    end
  end
end
