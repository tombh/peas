require 'spec_helper'

describe App do
  let(:app) { Fabricate :app }

  before :each do
    # NB: can't stub Peas::TMP_BASE because the module has already been loaded in spec_helper
    stub_const "Peas::APP_REPOS_PATH", "#{TMP_BASE}/repos"
    stub_const "Peas::TMP_TARS", "#{TMP_BASE}/tars"
    FileUtils.rm_rf '/tmp/peas/test/' # Hardcoded for sanity
  end

  describe 'Git repo setup on app creation' do
    it 'should create a bare git repo' do
      expect(File.exist?("#{Peas::APP_REPOS_PATH}/fabricated.git")).to be false
      expect(app.name).to eq 'fabricated'
      expect(File.exist?("#{app.local_repo_path}/hooks")).to be true
    end
    it 'should create a bare git repo' do
      expect(app.name).to eq 'fabricated'
      hook_contents = File.open("#{app.local_repo_path}/hooks/pre-receive").read
      expect(hook_contents).to include App::GIT_RECEIVER_PATH
    end
  end

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
      app.deploy('HEAD')
    end

    it 'should scale web process to 1 if there are no existing containers for the app' do
      expect(app).to receive(:scale).with({ 'web' => 1 }, 'deploy')
      app.deploy('HEAD')
    end

    it "should broadcast the app's URI for a custom domain" do
      Fabricate :setting, key: 'peas.domain', value: 'custom-domain.com'
      allow(app).to receive(:broadcast).and_call_original
      expect(app).to receive(:broadcast).with(
        %r{       Deployed to http:\/\/#{app.name}\.custom-domain\.com}
      )
      app.deploy('HEAD')
    end

    it "should rescale processes to the app's existing scaling profile" do
      3.times { |i| Fabricate :pea, app: app, process_type: 'web', docker_id: "web#{i}" }
      2.times { |i| Fabricate :pea, app: app, process_type: 'worker', docker_id: "worker#{i}" }
      expect(app).to receive(:scale).with(
        { 'web' => 3, 'worker' => 2 }, 'deploy'
      )
      app.deploy('HEAD')
    end
  end

  # See integration tests for actual testing of the buildstep process itself
  # Doesn't use :docker_creation_mock
  describe 'Builder', :with_worker do
    let(:builder) { Peas::Builder.new app, 'HEAD' }

    before :each do
      allow(app).to receive(:broadcast)
    end

    describe 'Builder prep' do

      before :each do
        create_non_bare_repo 'sweetpea', app.local_repo_path
      end

      it 'should tar a repo' do
        builder.tar_repo
        tarred_repo = "#{Peas::TMP_TARS}/#{app.name}.tar"
        expect(File.exist? tarred_repo).to eq true
        Peas.sh "tar -xf #{tarred_repo} -C #{TMP_BASE}"
        expect(File.exist? "#{TMP_BASE}/lathyrus.odoratus").to eq true
      end

      it 'should create a container ready for building', :docker do
        builder.tar_repo
        expect(builder.create_build_container).to be_a Docker::Container
      end
    end

    describe 'Building an image', :docker do
      before :each do
        create_non_bare_repo 'nodejs', app.local_repo_path
        builder.tar_repo
      end

      it 'should build an app resulting in a new Docker image' do
        container = builder.create_build_container
        allow(container).to receive(:attach).and_yield(:stdout, '-----> Node.js app detected')
        expect(app).to receive(:broadcast).with(/-----> Node.js app detected/)
        expect(container).to receive(:start)
        expect(container).to receive(:commit)
        expect(container).to receive(:delete)
        builder.create_app_image
      end

      it "should include the ENV vars saved in the app's config" do
        app.config_update('FOO' => 'BAR')
        container = builder.create_build_container
        # Hack to detect whether this is being recorded for the first time or not
        unless VCR.current_cassette.originally_recorded_at.nil?
          allow(container).to receive(:attach).and_yield(:stdout, '-----> Node.js app detected')
        end
        details = builder.create_app_image
        expect(details['Config']['Env']).to include("FOO=BAR")
      end

      it 'should deal with a failed build' do
        container = builder.create_build_container
        allow(container).to receive(:attach).and_yield(:stderr, 'Something went wrong')
        allow(container).to receive(:wait).and_return('StatusCode' => -1)
        expect(container).to_not receive(:commit)
        expect(container).to receive(:delete)
        expect {
          builder.create_app_image
        }.to raise_error Peas::PeasError, /Something went wrong/
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
