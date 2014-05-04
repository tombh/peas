require 'integration/integration_spec_helper'

describe 'The Peas PaaS Integration Tests', :integration do

  describe 'Settings' do
    it 'should update the domain' do
      response = cli 'settings --domain 127.0.0.1:4004'
      expect(response).to eq "New settings:\n{\n  \"domain\": \"http://127.0.0.1:4004\"\n}"
    end
  end

  describe 'Deploy' do
    # The test container runs on port 4004 to avoid conflicts with any dev/prod containers
    before :each do
      @peas_io.console 'Setting.create(key: "domain", value: "vcap.me:4004")'
    end

    it 'should deploy a basic nodejs app' do
      repo_path = TMP_PATH + '/node-js-sample'
      # Clone a very basic NodeJS app
      sh "rm -rf #{repo_path}"
      sh "cd #{TMP_PATH} && git clone https://github.com/heroku/node-js-sample"
      # Create the app in Peas
      response = cli 'create', repo_path
      expect(response).to eq "App 'node-js-sample' successfully created"
      # And deploy
      response = cli 'deploy', repo_path
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
  end
end
