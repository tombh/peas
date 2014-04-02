class DeployWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(name)
    10.times do
      store output: `date +"%T"`
      sleep 1
    end
    output = retrieve :output
  end
end