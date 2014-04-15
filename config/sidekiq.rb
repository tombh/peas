require './config/boot'
require 'sidekiq-status'

Dir["#{File.dirname(__FILE__)}/../api/workers/**/*.rb"].each { |f| require f }

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::Status::ClientMiddleware
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Status::ServerMiddleware, expiration: 30 * 60 # 30 mins
  end
  config.client_middleware do |chain|
    chain.add Sidekiq::Status::ClientMiddleware
  end
end