guard 'bundler' do
  watch('Gemfile')
end

group :server do
  guard :shotgun, port: ENV['PORT'] || '3004' do
    watch(%r{api/(.+)\.rb$})
    watch(%r{lib/(.+)\.rb$})
    watch(%r{config/(.+)\.rb$})
  end
end

sidekiq_args = [
  :require => './config/sidekiq.rb',
  :environment => 'development',
  :concurrency => 5
]
guard(:sidekiq, *sidekiq_args) do
  watch('config/sidekiq.rb')
  watch(%r{workers/(.+)\.rb$})
  watch(%r{lib/(.+)\.rb$})
end
