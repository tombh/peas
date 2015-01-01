require 'integration_helper'

describe 'The Peas PaaS Integration Tests', :integration do
  before :each do
    @cli = Cli.new REPO_PATH
  end

  it "should know we're inside a Docker container" do
    # The actual command is echoed, so if we matched an unconcatenated string we'd match the echo
    # and not the result.
    output = @peas_io.console "puts (!!Peas::DIND ? 'IN' : 'OUT') + 'DOCKER'"
    expect(output).to match /.*INDOCKER.*/
  end

  describe 'Settings' do
    it 'should update the domain' do
      response = @cli.run 'admin settings peas.domain 127.0.0.1:5443'
      expect(response).to match(/peas.domain 127\.0\.0\.1:5443/)
    end
  end

  context 'Apps' do
    before :each do
      # Create the app in Peas
      response = @cli.run 'create'
      expect(response).to eq "App 'node-js-sample' successfully created"
    end

    after :each do
      response = @cli.run 'destroy'
      expect(response).to eq "App 'node-js-sample' successfully destroyed"
    end

    describe 'Deploy' do
      it 'should deploy a basic nodejs app' do
        response = @cli.sh 'git push peas master'
        expect(response).to match(/-----> Installing dependencies/)
        expect(response).to match(/-----> Discovering process types/)
        expect(response).to match(/-----> Scaling process 'web:1'/)
        expect(response).to match %r{       Deployed to http:\/\/node-js-sample.vcap.me:5080}
        expect(response.lines.length).to be > 30
        # The app should be accessible
        sleep 5
        response = http_get "node-js-sample.vcap.me:5080"
        expect(response).to eq 'Hello World!'
      end

      it 'should deploy with a custom buildpack' do
        @cli.run 'config set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-nodejs.git'
        response = @cli.sh 'git push peas master'
        expect(response).to match(/Fetching custom buildpack/)
        sleep 5
        response = http_get "node-js-sample.vcap.me:5080"
        expect(response).to eq 'Hello World!'
      end
    end

    describe 'Config ENV vars' do
      it 'should set config for an app' do
        response = @cli.run 'config set FOO=BAR'
        expect(response).to eq '{"FOO"=>"BAR"}'
        @cli.sh 'git push peas master'
        sleep 5
        response = http_get "node-js-sample.vcap.me:5080"
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
      response = http_get 'node-js-sample.vcap.me:5080'
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
        sleep 3 # Give it a few moments to do the scaling
        response = @cli.run 'logs', 5
        expect(response).to match(/app\[web.2\]: > node-js-sample@0.1.0 start \/app/)
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
        response = http_get 'node-js-sample.vcap.me:5080/mongo'
        expect(response).to eq 'Barometer'
      end
    end
    describe 'Running commands' do
      it 'should list files in the app directory' do
        response = @cli.tty 'run ls'
        expect(response).to match(/Starting one-off pea for node-js-sample...done/)
        expect(response).to match(/.*Procfile.*app\.json.*/)
        expect(response).to match(/.*index\.js  package\.json.*/)
      end
    end
  end
end
