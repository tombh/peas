class MockWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(arg)
    store output: arg
    output = retrieve :output
  end
end