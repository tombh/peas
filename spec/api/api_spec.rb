require 'spec_helper'

describe Peas::API do
  include Rack::Test::Methods

  def app
    Peas::API
  end

  it "creates an app" do
    post "/create", {
      remote: 'git@github.com:test/test.git',
      first_sha: '5423b86dd1473916b16e7f5e6a331c87f380151c'
    }
    expect(last_response.status).to eq 201
    expect(App.count).to eq 1
    expect(App.first.first_sha).to eq "5423b86dd1473916b16e7f5e6a331c87f380151c"
    expect(JSON.parse(last_response.body)).to include({
      "remote" => "git@github.com:test/test.git",
      "first_sha" => "5423b86dd1473916b16e7f5e6a331c87f380151c",
      "name" => "test",
    })
  end

  it "deploys an app" do
    app = Fabricate :app
    get "/deploy", {first_sha: app.first_sha}
    expect(last_response.status).to eq 200
    expect(JSON.parse(last_response.body)).to have_key('job')
    expect(DeployWorker.jobs.size).to eq 1
    expect(DeployWorker).to have_enqueued_job(app.first_sha)
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
