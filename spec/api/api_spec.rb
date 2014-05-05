require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  let(:peas_app) {Fabricate :app}

  def app
    Peas::API
  end

  describe 'Apps' do
    it "creation" do
      post "/create", {
        remote: 'git@github.com:test/test.git',
        first_sha: '5423b86dd1473916b16e7f5e6a331c87f380151c'
      }
      expect(last_response.status).to eq 201
      expect(App.count).to eq 1
      expect(App.first.first_sha).to eq "5423b86dd1473916b16e7f5e6a331c87f380151c"
      expect(JSON.parse(last_response.body)).to include({
        'message' => "App 'test' successfully created"
      })
    end

    it "deploying" do
      get "/deploy", {first_sha: peas_app.first_sha}
      expect(last_response.status).to eq 200
      expect(JSON.parse(last_response.body)).to have_key('job')
      expect(ModelWorker.jobs.size).to eq 1
      expect(ModelWorker).to have_enqueued_job('App', peas_app.id.to_s, 'deploy')
    end

    it "scaling" do
      scaling_hash = {'web' => 3, 'worker' => 2}
      put "/scale", {first_sha: peas_app.first_sha, scaling_hash: scaling_hash.to_json}
      expect(last_response.status).to eq 200
      expect(JSON.parse(last_response.body)).to have_key('job')
      expect(ModelWorker.jobs.size).to eq 1
      expect(ModelWorker).to have_enqueued_job('App', peas_app.id.to_s, 'scale', scaling_hash)
    end

    describe 'Setting' do
      it "should create a new setting" do
        put "/settings", {domain: 'test.com'}
        expect(Setting.count).to eq 1
        domain = Setting.where(key: 'domain').first.value
        expect(domain).to eq 'test.com'
      end
    end

  end

  describe 'Long-running requests' do
    before do
      class MockWorker < ModelWorker
        def perform(arg)
          store output: arg
        end
      end
    end
    it "fetches the status of a job" do
      Sidekiq::Testing.inline! do
        @job = MockWorker.perform_async 'test-statuses'
      end
      get "/status", {job: @job}
      expect(last_response.status).to eq 200
      expect(JSON.parse(last_response.body)).to include({'output' => 'test-statuses'})
    end
  end

  describe 'Version check' do
    it "should log when the machine's Docker version is newer than Peas' tested version" do
      allow(Docker).to receive(:version).and_return({'Version' => '9999999999.9.9'})
      expect(Peas::Application.logger).to receive(:warn).with(/Using version/)
      get "/deploy", {first_sha: peas_app.first_sha}
    end
  end

end
