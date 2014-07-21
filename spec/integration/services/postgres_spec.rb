require 'spec_helper'

describe Peas::Services::Postgres, :service do
  before :each do
    @app = Fabricate :app
    @admin_conn = PG.connect(
      host: 'localhost',
      port: '5432',
      user: 'postgres',
      dbname: 'postgres'
    )
    # Ensure the DB is always clean
    silence_stream(STDERR) do # Gets rid of annoying NOTICE logs
      @admin_conn.exec "DROP DATABASE IF EXISTS #{@app.name}"
      @admin_conn.exec "DROP ROLE IF EXISTS #{@app.name}"
    end
    Setting.create(key: 'postgres.uri', value: 'postgresql://postgres@localhost:5432')
    uri = Peas::Services::Postgres.new(@app).create
    parsed = URI.parse uri
    @conn = PG.connect(
      host: parsed.host,
      port: parsed.port,
      user: parsed.user,
      password: parsed.password,
      dbname: @app.name
    )
  end

  context 'Creating a database' do
    after { Peas::Services::Postgres.new(@app).destroy }
    it 'should create a usable postgres db instance' do
      @conn.exec('CREATE TABLE spec (foo VARCHAR);')
      @conn.exec("INSERT INTO spec (foo) VALUES ('bar');")
      result = @conn.exec('SELECT * FROM spec;').to_a.first
      expect(result).to eq('foo' => 'bar')
    end
  end

  context 'Destroying a database' do
    it 'should destroy an existing postgres db instance and user' do
      Peas::Services::Postgres.new(@app).destroy
      result = @admin_conn.exec(
        "SELECT 1 AS result FROM pg_database WHERE datname='#{@app.name}'"
      ).to_a
      expect(result).to eq []
      result = @admin_conn.exec(
        "SELECT 1 FROM pg_roles WHERE rolname='#{@app.name}'"
      ).to_a
      expect(result).to eq []
    end
  end
end
