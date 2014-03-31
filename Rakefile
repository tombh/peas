require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'

require 'rspec/core'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  # do not run integration tests, doesn't work on TravisCI
  spec.pattern = FileList['spec/api/*_spec.rb']
end

task :environment do
  ENV["RACK_ENV"] ||= 'development'
  require File.expand_path("../config/environment", __FILE__)
end

desc "List all Grape API routes"
task :routes => :environment do
  Peas::API.routes.each do |route|
    puts route
  end
end

desc "Run pry console"
task :console do |t, args|
  ENV['RACK_ENV'] = args[:environment] || 'development'
  exec "pry -r ./config/environment"
end

require 'rubocop/rake_task'
Rubocop::RakeTask.new(:rubocop)

task default: [:rubocop, :spec]
