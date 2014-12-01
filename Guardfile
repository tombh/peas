require './contrib/guard_procfile'

guard 'bundler' do
  watch('Gemfile')
end

guard 'procfile_proxy'do
  watch('Gemfile.lock')
  watch('lib/proxy.rb')
end

guard 'procfile_api' do
  watch('Gemfile.lock')
  watch(%r{^(config|lib|api)/.*})
end

guard 'procfile_switchboard' do
  watch(%r{switchboard/server/.*})
end

guard 'procfile_gardener' do
  watch(%r{switchboard/clients/.*})
  watch(%r{^(lib/worker|api/models)/.*})
end
