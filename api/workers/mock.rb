class MockWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(arg)
    store output: "testing"
    output = retrieve :output
  end
end