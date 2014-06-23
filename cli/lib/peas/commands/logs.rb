desc 'Show logs for an app'
command :logs do |c|
  c.action do |global_options, options, args|
    API.stream_output "stream_logs.#{Git.first_sha}"
  end
end
