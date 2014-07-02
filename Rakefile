require 'rubygems'
require 'bundler'

ENV['RACK_ENV'] ||= "development"

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'

task :boot do
  require File.expand_path('../config/boot', __FILE__)
end

desc "List all Grape API routes"
task :routes => :boot do
  Peas::API.routes.each do |route|
    puts route
  end
end

desc "Run pry console"
task :console do |t, args|
  exec "pry -r ./config/boot"
end

# require 'rubocop/rake_task'
# Rubocop::RakeTask.new(:rubocop)
