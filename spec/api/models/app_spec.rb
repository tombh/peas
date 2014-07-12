require 'spec_helper'

describe App do
  let(:app) { Fabricate :app }

  describe 'Logging' do
    it 'should create a capped collection for logging' do
      expect(app.logs_collection).to be_a(Moped::Collection)
    end

    it 'should remove the capped collection when the app is removed' do
      db = Mongoid.default_session.options[:database]
      app_id = app._id
      collections = Mongoid::Sessions.default['system.namespaces'].find(
        name: "#{db}.#{app_id}_logs"
      )
      expect(collections.count).to be 1
      app.destroy
      collections = Mongoid::Sessions.default['system.namespaces'].find(
        name: "#{db}.#{app_id}_logs"
      )
      expect(collections.count).to be 0
    end

    it 'should add formatted lines to the logs' do
      app.log "If my calculations are correct,\nwhen this baby hits 88 miles per hour..."
      app.log "you're gonna see some serious shit."
      line = app.logs_collection.find.to_a[0][:line]
      expect(line).to include Date.today.to_s
      expect(line).to include 'app[general]: If my calculations are correct,'
      line = app.logs_collection.find.to_a[1][:line]
      expect(line).to include Date.today.to_s
      expect(line).to include 'app[general]: when this baby hits 88 miles per hour...'
      line = app.logs_collection.find.to_a[2][:line]
      expect(line).to include Date.today.to_s
      expect(line).to include "app[general]: you're gonna see some serious shit."
    end
  end

  describe 'deploy()', :with_worker do
    include_context :docker_creation_mock

    before :each do
      allow(App).to receive(:find_by).and_return(app)
      allow(app).to receive(:build) # Prevent build
      allow(app).to receive(:scale) # Prevent scaling
    end

    it 'should trigger a build' do
      expect(app).to receive(:build)
      app.deploy
    end

    it 'should scale web process to 1 if there are no existing containers for the app' do
      expect(app).to receive(:scale).with({ 'web' => 1 }, 'deploy')
      app.deploy
    end

    it "should broadcast the app's URI for a custom domain" do
      Fabricate :setting, key: 'domain', value: 'custom-domain.com'
      allow(app).to receive(:broadcast).and_call_original
      expect(app).to receive(:broadcast).with(
        %r{       Deployed to http:\/\/#{app.name}\.custom-domain\.com}
      )
      app.deploy
    end

    it "should rescale processes to the app's existing scaling profile" do
      3.times { |i| Fabricate :pea, app: app, process_type: 'web', docker_id: "web#{i}" }
      2.times { |i| Fabricate :pea, app: app, process_type: 'worker', docker_id: "worker#{i}" }
      expect(app).to receive(:scale).with(
        { 'web' => 3, 'worker' => 2 }, 'deploy'
      )
      app.deploy
    end
  end

  describe 'build()' do
    # Doesn't use :docker_creation_mock

    before :each do
      stub_const "Peas::TMP_REPOS", '/tmp/peas/test/repos'
      stub_const "Peas::TMP_TARS", '/tmp/peas/test/tars'
      FileUtils.rm_rf '/tmp/peas/test/'
    end

    context 'Fetching and tarring an app for Buildstep' do
      before :each do
        allow(app).to receive(:sh)
        allow(app).to receive(:broadcast)
      end

      it 'should create the necessary directories' do
        app._fetch_and_tar_repo
        expect(File.exist? Peas::TMP_REPOS).to eq true
        expect(File.exist? Peas::TMP_TARS).to eq true
      end

      it "should clone the app when the repo doesn't exist locally" do
        expect(app).to receive(:sh).with(/git clone .* #{Peas::TMP_REPOS}\/#{app.name}/)
        app._fetch_and_tar_repo
      end

      it 'should only pull updates when the repo already exists locally' do
        FileUtils.mkdir_p "#{Peas::TMP_REPOS}/fabricated"
        expect(app).to receive(:sh).with(/cd #{Peas::TMP_REPOS}\/#{app.name} .* git pull/)
        app._fetch_and_tar_repo
      end
    end

    context 'The build process itself' do

      it 'should build an app resulting in a new Docker image', :docker do
        # Use the nodejs example just because it builds so quickly
        app = Fabricate :app,
                        remote: 'https://github.com/heroku/node-js-sample.git',
                        name: 'node-js-sample'
        # Hack to detect whether this is being recorded for the first time or not
        unless VCR.current_cassette.originally_recorded_at.nil?
          allow(app).to receive(:_fetch_and_tar_repo)
        end
        allow(app).to receive(:broadcast)
        expect(app).to receive(:broadcast).with(/       Node.js app detected/)
        expect(app).to receive(:broadcast).with(/-----> Installing dependencies/)
        expect(app).to receive(:broadcast).with(/       Procfile declares types -> web/)
        expect_any_instance_of(Docker::Container).to receive(:commit)
        expect_any_instance_of(Docker::Container).to receive(:delete)
        app.build
      end

      it "should include the ENV vars saved in the app's config", :docker do
        app = Fabricate :app,
                        remote: 'https://github.com/heroku/node-js-sample.git',
                        name: 'node-js-sample',
                        config: { 'FOO' => 'BAR' }
        allow(app).to receive(:broadcast)
        details = app.build
        expect(details['Config']['Env']).to include("FOO=BAR")
      end

      it 'should deal with a failed build', :docker do
        app = Fabricate :app,
                        remote: 'https://github.com/saddleback/hello-world-cpp.git',
                        name: 'hello-world-cpp'
        # Hack to detect whether this is being recorded for the first time or not
        unless VCR.current_cassette.originally_recorded_at.nil?
          allow(app).to receive(:_fetch_and_tar_repo)
        end
        allow(app).to receive(:broadcast)
        expect_any_instance_of(Docker::Container).to_not receive(:commit)
        expect_any_instance_of(Docker::Container).to receive(:delete)
        expect {
          app.build
        }.to raise_error RuntimeError, /Unable to select a buildpack/
      end
    end
  end

  describe 'scale()', :with_worker do
    include_context :docker_creation_mock

    it 'should create peas' do
      allow(app).to receive(:broadcast)
      app.scale(web: 3, worker: 2)
      expect(Pea.where(app: app).where(process_type: 'web').count).to eq 3
      expect(Pea.where(app: app).where(process_type: 'worker').count).to eq 2
    end
  end

  describe 'restart()', :with_worker do
    include_context :docker_creation_mock

    it 'should restart all peas belonging to an app' do
      allow(app).to receive(:broadcast)
      app.scale(web: 3, worker: 2)
      expect(app.peas).to receive(:destroy_all).and_call_original
      expect(Pea).to receive(:create!).exactly(5).times.and_call_original
      app.restart
    end
  end

end
