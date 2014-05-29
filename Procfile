web: bundle exec rackup -s Puma -p 4000 --env ${RACK_ENV:=development}
sidekiq: bundle exec sidekiq --verbose --environment ${RACK_ENV:=development} --require ./config/sidekiq.rb --concurrency 5