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

module ::Guard
  class Nats < Guard
    def start
      puts "Starting nats-server"
      # TODO check if already running
      @child = IO.popen("bundle exec nats-server")
      puts "NATs running with PID #{@child.pid}"
      $?.success?
    end

    def stop
      if @child.pid
        puts "Sending TERM signal to nats-server (#{@child.pid})"
        Process.kill("TERM", @child.pid)
        true
      end
    end

    def reload
      stop
      start
    end

    def run_all
      true
    end

    def run_on_change(paths)
      true
    end

  end
end

guard 'nats' do
  watch('Gemfile.lock')
end
