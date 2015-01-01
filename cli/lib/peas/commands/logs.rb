desc 'Show logs for an app'
command :logs do |c|

  c.desc "Follow logs as new lines are created"
  c.switch [:f, :follow]

  c.action do |_global_options, options, _args|
    follow = options[:follow] ? ' follow' : ''
    API.stream_output "stream_logs.#{Git.name_from_remote}#{follow}"
  end
end
