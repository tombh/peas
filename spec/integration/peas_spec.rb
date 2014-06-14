require 'integration_helper'

describe 'The Peas PaaS Integration Tests', :integration do
  before :each do
    @cli = Cli.new REPO_PATH
  end

  describe 'Settings' do
    it 'should update the domain' do
      response = @cli.run 'settings --domain 127.0.0.1:4004'
      expect(response).to eq(
        "\r\nNew settings:\r\n{\r\n  \"domain\": \"http://127.0.0.1:4004\"\r\n}\r\n"
      )
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
        expect(response.lines.length).to be > 30
        # The app should be accessible
        sleep 5
        response = http_get "node-js-sample.vcap.me:4004"
        expect(response).to eq 'Hello World!'
      end

      it 'should use a custom buildpack proving build time env vars work' do
        @cli.run 'config set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-nodejs.git'
        response = @cli.run 'deploy'
        expect(response).to include 'Fetching custom buildpack'
        sleep 5
        response = http_get "node-js-sample.vcap.me:4004"
        expect(response).to eq 'Hello World!'
      end
    end

    describe 'Config ENV vars' do
      it 'should set config for an app' do
        response = @cli.run 'config set FOO=BAR'
        expect(response).to eq '{"FOO"=>"BAR"}'
        @cli.run 'deploy'
        sleep 5
        response = http_get "node-js-sample.vcap.me:4004"
        expect(response).to eq 'Hello BAR!'
      end
      it 'should delete config for an app' do
        response = @cli.run 'config set FOO=BAR'
        expect(response).to eq '{"FOO"=>"BAR"}'
        response = @cli.run 'config rm FOO'
        expect(response).to eq ''
      end
      it 'should list config for an app' do
        response = @cli.run 'config set FOO=BAR'
        response = @cli.run 'config set MOO=CAR'
        response = @cli.run 'config'
        expect(response).to eq "{\"FOO\"=>\"BAR\"}\r\n{\"MOO\"=>\"CAR\"}\r\n"
      end
    end
  end

  describe 'Features of deployed apps', :maintain_test_env do
    before :all do
      @cli = Cli.new REPO_PATH
      response = @cli.run 'create'
      expect(response).to eq "App 'node-js-sample' successfully created"
      response = @cli.run 'deploy'
      sleep 5
      response = http_get 'node-js-sample.vcap.me:4004'
      expect(response).to eq 'Hello World!'
    end
    describe 'Logs' do
      it 'should stream logs' do
        response = @cli.run 'logs', 5
        expect(response).to include 'Node app is running at localhost:5000'
      end
    end
  end
end
