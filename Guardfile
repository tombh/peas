guard 'bundler' do
  watch('Gemfile')
end

group :server do
  guard 'puma', port: ENV['PORT'] || '4000', bind: 'tcp://0.0.0.0', quiet: false do
    watch('Gemfile.lock')
    watch(%r{^config|lib|api/.*})
  end
end

sidekiq_args = [
  :require => './config/sidekiq.rb',
  :environment => 'development',
  :concurrency => 5
]
guard(:sidekiq, *sidekiq_args) do
  watch(%r{^config|lib|api/.*})
end
