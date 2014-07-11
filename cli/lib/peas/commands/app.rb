desc 'Create an app'
command :create do |c|
  c.action do |_global_options, _options, _args|
    @api.request :post, "/app/#{Git.first_sha}",
                 remote: Git.remote

  end
end

desc 'Deploy an app'
command :deploy do |c|
  c.action do |_global_options, _options, _args|
    @api.request :get, "/app/#{Git.first_sha}/deploy"
  end
end

desc 'Scale an app'
long_desc <<-EOF
For example: peas scale web=3 worker=2
EOF
command :scale do |c|
  c.action do |_global_options, _options, args|
    if args.length == 0
      exit_now! "Please provide scaling arguments in the form: web=3 worker=2"
    end
    scaling_hash = {}
    args.each do |arg|
      parts = arg.split('=', 2)
      process_type = parts[0]
      quantity = parts[1]
      scaling_hash[process_type] = quantity
    end
    @api.request :put, "/app/#{Git.first_sha}/scale",
                 scaling_hash: scaling_hash.to_json

  end
end
