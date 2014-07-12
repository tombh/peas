source 'http://rubygems.org'

gem 'foreman'
gem 'puma'
gem 'rack'
gem 'grape', github: 'intridea/grape'
gem 'grape-swagger'
gem 'mongoid', github: 'mongoid/mongoid'
gem 'celluloid'
gem 'celluloid-io'
gem 'docker-api', :require => 'docker'
gem 'rake'

# Services
gem 'pg'

group :development do
  gem 'guard'
  gem 'guard-bundler'
  gem 'guard-puma'
  gem 'rb-inotify', :require => false
  gem 'pry'
end

group :test do
  gem 'rspec'
  gem 'rack-test'
  gem 'fabrication'
  gem 'webmock'
  gem 'vcr'
  gem 'rubocop'
end
