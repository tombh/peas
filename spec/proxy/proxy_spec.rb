require 'spec_helper'

describe 'Proxy' do
  let(:app) { Fabricate :app }
  include_context :docker_creation_mock

  it 'should detect the app name and proxy to one of its containers' do
    allow_any_instance_of(App).to receive(:scale) # Prevent scaling
	  pea = Fabricate :pea, app: app
    request = double('request', host: 'fabricated.vcap.me', path: '/somewhere')
    redirect = Peas.proxy request
    expect(redirect.to_s).to eq "http://localhost:#{pea.port}/somewhere"
  end

  it 'should not forward if the app has no web containers' do
    request = double('request', host: 'fabricated.vcap.me', path: '/somewhere')
    redirect = Peas.proxy request
    expect(redirect).to eq false
  end

end
