require 'guard/plugin'

module Guard
  class BaseGuard < ::Guard::Plugin
    def log(msg)
      puts "GUARD: #{msg}"
    end

    def service_name
      self.class.name
    end

    def start
      log "Starting #{service_name}"
      # TODO: check if already running
      @pid = spawn command
      log "#{service_name} running with PID #{@pid}"
      @pid
    end

    def stop
      return unless @pid
      log "Sending KILL signal to #{service_name} PID #{@pid}"
      Process.kill("KILL", @pid)
      true
    end

    def reload
      stop
      start
    end

    def run_all
      true
    end

    def run_on_changes
      reload
    end
  end
end

procfile = YAML.load File.open 'Procfile'
procfile.each_pair do |process, command|
  klass_name = "Procfile#{process.capitalize}"
  # Create a class with name like, ProcfileAPI
  Guard.const_set klass_name, Class.new(Guard::BaseGuard)
  # Give the class the command() method
  Guard.const_get(klass_name).module_eval do
    define_method(:command) do
      command
    end
  end
end
