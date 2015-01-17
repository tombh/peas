desc 'List all apps'
command :apps do |c|
  c.action do |_global_options, _options, _args|
    @api.request(:get, "/app")
  end
end

desc 'Create an app'
command :create do |c|
  c.action do |_global_options, _options, _args|
    unless Git.remote('peas').empty?
      exit_now! "This repo already has an app (#{Git.name_from_remote}) associated with it.", 1
    end
    params = {
      'muse' => Git.name_from_remote(Git.remote('origin')),
    }
    response = @api.request(
      :post,
      '/app',
      params
    )
    Git.add_remote response['remote_uri']
  end
end

desc 'Destroy an app'
command :destroy do |c|
  c.action do |_global_options, _options, _args|
    @api.request(
      :delete,
      "/app/#{Git.name_from_remote}"
    )
    Git.remove_remote
  end
end

desc 'Scale an app'
long_desc <<-EOF
For example: peas scale web=3 worker=2
EOF
command :scale do |c|
  c.action do |_global_options, _options, args|
    if args.length == 0
      exit_now! "Please provide scaling arguments in the form: web=3 worker=2", 1
    end
    scaling_hash = {}
    args.each do |arg|
      parts = arg.split('=', 2)
      process_type = parts[0]
      quantity = parts[1]
      scaling_hash[process_type] = quantity
    end
    @api.request(
      :put,
      "/app/#{Git.name_from_remote}/scale",
      'scaling_hash' => scaling_hash.to_json
    )
  end
end

desc 'Run one-off commands'
long_desc <<-EOF
For example: peas run rake db:migrate
EOF
command :run do |c|
  c.action do |_global_options, _options, args|
    exit_now!("Please provide a command to run", 1) if args.length == 0
    socket = API.switchboard_connection
    socket.puts "tty.#{Git.name_from_remote}"
    tty_command = args.join ' '
    socket.puts tty_command
    API.duplex_socket socket
  end
end
