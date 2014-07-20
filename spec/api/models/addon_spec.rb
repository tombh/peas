require 'spec_helper'

describe Addon, :mock_worker do

  # Use the MongoDB service seeing as it's already a dependency of Peas
  before :each do
    allow(@mock_worker).to receive(:restart)
    session = Moped::Session.new(['localhost:27017'])
    session.use :fabricated
    session.drop
    Setting.create(key: 'mongodb.uri', value: 'mongodb://localhost:27017')
    @app = Fabricate :app
  end

  context 'Creating addons' do
    after :each do
      @app.destroy
    end

    it "should add a service instance's connection URI to the app's config" do
      expect(@app.config['MONGODB_URI']).to match(
        %r{mongodb://fabricated:.*@localhost:27017/fabricated}
      )
    end

    it "should create a usable service instance" do
      uri = @app.config['MONGODB_URI']
      parsed = URI.parse uri
      session = Moped::Session.new ["#{parsed.host}:#{parsed.port}"]
      session.use @app.name
      session.login parsed.user, parsed.password
      session[:spec].insert(foo: 'bar')
      expect(session[:spec].find(foo: 'bar').count).to eq 1
    end
  end

  context 'Destroying addons' do
    it 'should remove a service instance' do
      expect(Addon.count).to eq 1
      @app.destroy
      expect(Addon.count).to eq 0
      dbs = Moped::Session.new(['localhost:27017']).databases['databases'].map { |d| d['name'] }
      expect(dbs.include? 'fabricated').to be false
    end
  end
end
