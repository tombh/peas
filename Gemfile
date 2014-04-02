source 'http://rubygems.org'

gem 'rack'
gem 'grape', github: 'intridea/grape'
gem 'grape-swagger'
gem 'mongoid', github: 'mongoid/mongoid'
gem 'sidekiq'
gem 'sidekiq-status'

group :development do
  gem 'rake'
  gem 'guard'
  gem 'guard-bundler'
  gem 'guard-shotgun', :git => 'https://github.com/rchampourlier/guard-shotgun.git'
  gem 'guard-sidekiq'
  gem 'rb-inotify'
  gem 'rubocop'
end

group :test do
  gem 'rspec'
  gem 'rspec-sidekiq'
  gem 'rack-test'
  gem 'capybara'
  gem 'selenium-webdriver'
end
