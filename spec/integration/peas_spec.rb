require 'integration_helper'

describe 'The Peas PaaS Integration Tests', :integration do
  before :each do
    @cli = Cli.new REPO_PATH
  end

  describe 'Settings' do
    it 'should update the domain' do
      response = @cli.run 'admin settings peas.domain 127.0.0.1:4004'
      expect(response).to match(/peas.domain 127\.0\.0\.1:4004/)
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
        response = @cli.sh 'git push peas master'
        expect(response).to match %r{-----> Fetching https:\/\/github.com\/tombh\/node-js-sample.git}
        expect(response).to match(/-----> Installing dependencies/)
        expect(response).to match(/-----> Discovering process types/)
        expect(response).to match(/-----> Scaling process 'web:1'/)
        expect(response).to match %r{       Deployed to http:\/\/node-js-sample.vcap.me:4004}
        expect(response.lines.length).to be > 30
        # The app should be accessible
        sleep 5
        response = http_get "node-js-sample.vcap.me:4004"
        expect(response).to eq 'Hello World!'
      end

      it 'should deploy with a custom buildpack' do
        @cli.run 'config set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-nodejs.git'
        response = @cli.sh 'git push peas master'
        expect(response).to match(/Fetching custom buildpack/)
        sleep 5
        response = http_get "node-js-sample.vcap.me:4004"
        expect(response).to eq 'Hello World!'
      end
    end

    describe 'Config ENV vars' do
      it 'should set config for an app' do
        response = @cli.run 'config set FOO=BAR'
        expect(response).to eq '{"FOO"=>"BAR"}'
        @cli.sh 'git push peas master'
        sleep 5
        response = http_get "node-js-sample.vcap.me:4004"
        expect(response).to eq 'Hello BAR!'
      end
      it 'should delete config for an app' do
        response = @cli.run 'config set FOO=BAR'
        expect(response).to eq '{"FOO"=>"BAR"}'
        response = @cli.run 'config rm FOO'
        expect(response).to eq '{}'
      end
      it 'should list config for an app' do
        @cli.run 'config set FOO=BAR'
        @cli.run 'config set MOO=CAR'
        response = @cli.run 'config'
        expect(response).to eq "{\"FOO\"=>\"BAR\", \"MOO\"=>\"CAR\"}"
      end
    end
  end

  describe 'Features of deployed apps', :maintain_test_env do
    before :all do
      @cli = Cli.new REPO_PATH
      @cli.run 'admin settings mongodb.uri mongodb://10.0.42.1:27017'
      response = @cli.run 'create'
      expect(response).to eq "App 'node-js-sample' successfully created"
      @cli.sh 'git push peas master'
      sleep 5
      response = http_get 'node-js-sample.vcap.me:4004'
      expect(response).to eq 'Hello World!'
    end
    describe 'Config' do
      it 'should set config and restart app' do
        response = @cli.run 'config set SUCH=CONFIG'
        expect(response).to match(/"SUCH"=>"CONFIG"}/)
        response = @cli.run 'logs', 5
        expect(response).to match(/app\[App.restart.worker\]: Restarting all processes.../)
      end
    end
    describe 'Scaling' do
      it 'should scale an app' do
        response = @cli.run 'scale web=2'
        expect(response).to match(/Scaling process 'web:2'/)
        response = @cli.run 'logs', 5
        expect(response).to match(/app\[web.1\]: Node app is running at localhost:5000/)
      end
    end
    describe 'Addons' do
      it 'should auto add an addon if a service URI is present' do
        response = @cli.run 'config'
        # 10.0.42.1 seems to be the default IP for the internal DinD interface
        expect(response).to match(
          %r{"MONGODB_URI"=>"mongodb://nodejssample:[a-z0-9]*@10.0.42.1:27017/nodejssample"}
        )
      end
      it 'should enable an app to interact with a service' do
        response = http_get 'node-js-sample.vcap.me:4004/mongo'
        expect(response).to eq 'Barometer'
      end
    end
  end
end
