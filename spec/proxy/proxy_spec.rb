require 'spec_helper'

describe Peas::Proxy do
  let(:app) { Fabricate :app }
  let(:pea) { Fabricate :pea, app: app }
  let(:stack) { Peas::Proxy.new }
  let(:request) { Rack::MockRequest.new stack }
  include_context :docker_creation_mock

  it 'should detect the app name and proxy to one of its containers' do
    stub_request(:get, "http://#{pea.pod.hostname}:#{pea.port}/somewhere").to_return(:status => 200, :body => "over the rainbow")
    expect(Net::HTTP).to receive(:start).with('localhost', 49175).and_call_original
    response = request.get('http://fabricated.vcap.me/somewhere')
    expect(response.body).to eq 'over the rainbow'
  end

  it "should not forward if the request doesn't involve an app" do
    response = request.get('http://nonexistentapp.vcap.me/somewhere')
    expect(response.body).to eq 'Peas has no application at this address'
  end

  it 'should raise a ProxyError with logs from the app when forwarding fails' do
    stub_request(:get, "http://#{pea.pod.hostname}:#{pea.port}/somewhere").to_raise(EOFError)
    app.log "Something's not right :("
    expect(Peas::API.logger).to receive(:error).with([/Something's not right :\(/])
    response = request.get('http://fabricated.vcap.me/somewhere')
    expect(response.body).to eq "The application 'fabricated' didn't respond. Please check the logs and try again."
  end
end
