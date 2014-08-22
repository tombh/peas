require 'spec_helper'

describe Peas::Services::Mongodb, :service do
  before :each do
    Peas.sh 'mongo fabricated --eval "db.dropUser(\'fabricated\');"'
    Peas.sh 'mongo fabricated --eval "db.dropDatabase();"'
    @app = Fabricate :app
    Setting.create(key: 'mongodb.uri', value: 'mongodb://localhost:27017')
    uri = Peas::Services::Mongodb.new(@app).create
    parsed = URI.parse uri
    @session = Moped::Session.new ["#{parsed.host}:#{parsed.port}"]
    @session.use @app.name
    @session.login parsed.user, parsed.password
    @session[:spec].insert(foo: 'bar')
  end

  it 'should create a usable mongo db instance' do
    expect(@session[:spec].find(foo: 'bar').count).to eq 1
    Peas::Services::Mongodb.new(@app).destroy
  end

  it 'should destroy an existing mongo db instance' do
    expect(list_mongo_dbs.include? 'fabricated').to be true
    Peas::Services::Mongodb.new(@app).destroy
    expect(list_mongo_dbs.include? 'fabricated').to be false
  end
end
