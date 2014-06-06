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
  class MessageServer < Guard
    def start
      puts "Starting messaging server"
      # TODO check if already running
      @pid = spawn 'bundle exec ./messaging/bin/server'
      puts "Messaging server running with PID #{@pid}"
      @pid
    end

    def stop
      if @pid
        puts "Sending TERM signal to messaging server (#{@pid})"
        Process.kill("TERM", @pid)
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

    def run_on_changes(paths)
      reload
    end

  end
end

guard 'message_server' do
  watch('messaging/.*')
end