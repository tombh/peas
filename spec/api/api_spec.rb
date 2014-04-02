require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  it "creates an app" do
    post "/create", {name: 'test-app'}
    expect(last_response.status).to eq 201
    expect(JSON.parse(last_response.body)).to include({'name' => 'test-app'})
  end

  it "deploys an app" do
    get "/deploy", {name: 'test-app'}
    expect(last_response.status).to eq 200
    expect(JSON.parse(last_response.body)).to have_key('job')
    expect(DeployWorker.jobs.size).to eq 1
    expect(DeployWorker).to have_enqueued_job('test-app')
  end

  it "fetches the status of a job" do
    job = MockWorker.perform_async 'test-statuses'
    MockWorker.drain
    get "/status", {job: job}
    expect(last_response.status).to eq 200
    expect(JSON.parse(last_response.body)).to include({'output' => 'testing'})
  end

end
