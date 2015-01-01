require './contrib/guard_procfile'

env = { "PEAS_API_PORT" => '4443', "PEAS_PROXY_PORT" => '4080' }

guard 'bundler' do
  watch('Gemfile')
end

guard 'procfile_proxy', env: env do
  watch('Gemfile.lock')
  watch('lib/proxy.rb')
end

guard 'procfile_api', env: env do
  watch('Gemfile.lock')
  watch(%r{^(config|lib|api)/.*})
end

guard 'procfile_switchboard', env: env do
  watch(%r{switchboard/server/.*})
end

guard 'procfile_gardener', env: env do
  watch(%r{switchboard/clients/.*})
  watch(%r{^(lib/worker|api/models)/.*})
end
