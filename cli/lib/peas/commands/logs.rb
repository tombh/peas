desc 'Show logs for an app'
command :logs do |c|
  c.action do |_global_options, _options, _args|
    API.stream_output "stream_logs.#{Git.name_from_remote}"
  end
end
