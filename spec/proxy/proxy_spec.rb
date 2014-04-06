require 'spec_helper'

describe 'Proxy' do
  let(:app) { Fabricate :app }

  it "should detect the app name and proxy to one of its containers" do
	  Fabricate :pea, app: app
    request = double('request', host: 'fabricated.vcap.me', path: '/somewhere')
    redirect = Peas.proxy request
    expect(redirect.to_s).to eq 'http://localhost:5000/somewhere'
  end

  it "should not forward if the app has no web containers" do
    request = double('request', host: 'fabricated.vcap.me', path: '/somewhere')
    redirect = Peas.proxy request
    expect(redirect).to eq false
  end

end
