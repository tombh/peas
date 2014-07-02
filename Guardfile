require 'guard/plugin'

guard 'bundler' do
  watch('Gemfile')
end

group :server do
  guard 'puma', port: ENV['PORT'] || '4000', bind: 'tcp://0.0.0.0', quiet: false do
    watch('Gemfile.lock')
    watch(%r{^(config|lib|api)/.*})
  end
end

module ::Guard
  class BaseGuard < ::Guard::Plugin
    def log msg
      puts "GUARD: #{msg}"
    end

    def service_name
      self.class.name
    end

    def start
      log "Starting #{service_name}"
      # TODO check if already running
      @pid = spawn command
      log "#{service_name} running with PID #{@pid}"
      @pid
    end

    def stop
      if @pid
        log "Sending KILL signal to #{service_name} PID #{@pid}"
        Process.kill("KILL", @pid)
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

module ::Guard
  class SwitchboardServer < BaseGuard
    def command
      'bundle exec ./bin/switchboard'
    end
  end
end
guard 'switchboard_server' do
  watch(%r{switchboard/server/.*})
end

module ::Guard
  class SwitchboardClients < BaseGuard
    def command
      'bundle exec ./bin/gardener'
    end
  end
end
guard 'switchboard_clients' do
  watch(%r{switchboard/clients/.*})
end
