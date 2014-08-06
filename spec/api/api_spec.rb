require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  let(:peas_app) { Fabricate :app }
  let(:uuid) { 'b962c3db-9170-4962-9a7b-91db1a809c91' }

  def app
    Peas::API
  end

  before :each do
    @socket = instance_double 'TCPSocket'
    allow(@socket).to receive(:close)
    allow(Peas::Switchboard).to receive(:connection).and_return(@socket)
    allow(SecureRandom).to receive(:uuid).and_return(uuid)
  end

  describe 'Apps' do
    it "should list all apps" do
      expect(peas_app).to be_a App
      get '/app'
      expect(last_response.status).to eq 200
      expect(JSON.parse(last_response.body)).to include(
        'message' => ['fabricated']
      )
    end

    it "should create an app" do
      post '/app', muse: 'test-test'
      expect(last_response.status).to eq 201
      expect(App.count).to eq 1
      expect(App.first.name).to eq "test-test"
      expect(JSON.parse(last_response.body)).to include(
        'message' => "App 'test-test' successfully created"
      )
      expect(JSON.parse(last_response.body)).to include(
        'remote_uri' => 'ssh://git@vcap.me:4000/test-test'
      )
    end

    it "should come up with a unique name when muse is blank" do
      stub_request(:get, "http://randomword.setgetgo.com/get.php")
        .to_return(body: "hipster")
      post '/app'
      expect(last_response.status).to eq 201
      expect(App.count).to eq 1
      expect(App.first.name).to eq "hipster"
    end

    it "should prepend an adverb when name is already taken" do
      allow(File).to receive(:open).with("#{Peas.root}/lib/adverbs.txt").and_return("hipsterly")
      expect(peas_app).to be_a App
      expect(App.first.name).to eq 'fabricated'
      post '/app', muse: 'fabricated'
      expect(last_response.status).to eq 201
      expect(App.count).to eq 2
      expect(App.where(:name.ne => 'fabricated').first.name).to eq "hipsterly-fabricated"
    end

    it "should destroy an app" do
      expect(peas_app).to be_a App
      delete "/app/#{peas_app.name}"
      expect(last_response.status).to eq 200
      expect { App.find(peas_app) }.to raise_error Mongoid::Errors::DocumentNotFound
      expect(JSON.parse(last_response.body)).to include(
        'message' => "App 'fabricated' successfully destroyed"
      )
    end

    it "should deploy an app" do
      allow(@socket).to receive(:puts).exactly(4).times
      job = {
        parent_job: uuid,
        current_job: uuid,
        model: 'App',
        id: peas_app._id.to_s,
        method: 'deploy',
        args: []
      }
      expect(@socket).to receive(:puts).with(job.to_json)
      get "/app/#{peas_app.name}/deploy"
      expect(last_response.status).to eq 200
      expect(JSON.parse(last_response.body)['job']).to eq uuid
    end

    it "should scale an app" do
      scaling_hash = { 'web' => 3, 'worker' => 2 }
      allow(@socket).to receive(:puts).exactly(4).times
      job = {
        parent_job: uuid,
        current_job: uuid,
        model: 'App',
        id: peas_app._id.to_s,
        method: 'scale',
        args: [scaling_hash]
      }.to_json
      expect(@socket).to receive(:puts).with(job)
      put "/app/#{peas_app.name}/scale", scaling_hash: scaling_hash.to_json
      expect(last_response.status).to eq 200
      expect(JSON.parse(last_response.body)['job']).to eq uuid
    end

    it "should return a 404 if an app can't be found" do
      get "/app/sha1doesnoteixst/deploy"
      expect(last_response.status).to eq 404
      expect(JSON.parse(last_response.body)).to have_key('error')
      expect(JSON.parse(last_response.body)).to eq('error' => 'App does not exist')
    end

    describe 'Settings' do
      it 'should list defaults and available services' do
        Setting.create key: 'mongodb.uri', value: 'mongodb://uri'
        get '/admin/settings'
        response = JSON.parse(last_response.body)['message']
        expect(response['defaults']['peas.domain']).to eq Setting.retrieve('peas.domain')
        expect(response['services']['mongodb.uri']).to eq Setting.retrieve('mongodb.uri')
      end

      it "should create a new setting" do
        put '/admin/settings', domain: 'test.com'
        expect(Setting.count).to eq 1
        domain = Setting.where(key: 'domain').first.value
        expect(domain).to eq 'test.com'
      end
    end

    describe 'Config ENV vars' do
      it 'should return 400 if no config values are given' do
        put "/app/#{peas_app.name}/config"
        expect(last_response.status).to eq 400
      end

      it 'should create a new config hash for an existing app', :mock_worker do
        expect(@mock_worker).to receive(:restart)
        put "/app/#{peas_app.name}/config", vars: { 'foo' => 'bar' }.to_json
        expect(last_response.status).to eq 200
        message = JSON.parse(last_response.body)['message']
        expect(message).to eq('foo' => 'bar')
      end

      context "for app's with existing config" do
        before :each do
          peas_app.config = {
            'foo' => 'bar',
            'mange' => 'tout'
          }
          peas_app.save!
        end

        it 'should return all existing config vars' do
          get "/app/#{peas_app.name}/config"
          expect(last_response.status).to eq 200
          message = JSON.parse(last_response.body)['message']
          expect(message).to eq('foo' => 'bar', 'mange' => 'tout')
        end

        it 'should update an existing config var', :mock_worker do
          expect(@mock_worker).to receive(:restart)
          put "/app/#{peas_app.name}/config", vars: { 'foo' => 'peas' }.to_json
          expect(last_response.status).to eq 200
          message = JSON.parse(last_response.body)['message']
          expect(message).to eq('foo' => 'peas', 'mange' => 'tout')
        end

        it 'should delete existing config var' do
          delete "/app/#{peas_app.name}/config", keys: ['foo'].to_json
          expect(last_response.status).to eq 200
          message = JSON.parse(last_response.body)['message']
          expect(message).to eq('mange' => 'tout')
        end
      end
    end

  end

  describe 'Version check' do
    it "should log when the machine's Docker version is newer than Peas' tested version" do
      allow(Docker).to receive(:version).and_return('Version' => '9999999999.9.9')
      expect(Peas::API.logger).to receive(:warn).with(/Using version/)
      get "/app/#{peas_app.name}/config"
    end
  end

end
