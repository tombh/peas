source 'http://rubygems.org'

gem 'foreman'
gem 'puma'
gem 'rack'
gem 'grape', github: 'intridea/grape'
gem 'grape-swagger'
gem 'mongoid', github: 'mongoid/mongoid'
gem 'celluloid'
gem 'celluloid-io'
gem 'sidekiq'
gem 'sidekiq-status'
gem 'docker-api', :require => 'docker'
gem 'rake'

group :development do
  gem 'guard'
  gem 'guard-bundler'
  gem 'guard-puma'
  gem 'guard-sidekiq'
  gem 'rb-inotify', :require => false
  gem 'pry'
end

group :test do
  gem 'rspec'
  gem 'rspec-sidekiq'
  gem 'rack-test'
  gem 'database_cleaner'
  gem 'fabrication'
  gem 'webmock'
  gem 'vcr'
  gem 'rubocop'
end
