require 'spec_helper'

describe 'Proxy' do
  let(:app) { Fabricate :app }
  let(:image) {
    double(
      start: double(
        info: {'id' => '123abc'},
        json: {
          'NetworkSettings' => {
            'Ports' =>  {
              '5000' => [{
                'HostPort' => '45617'
              }]
            }
          }
        }
      )
    )
  }

  it 'should detect the app name and proxy to one of its containers' do
    allow_any_instance_of(App).to receive(:scale) # Prevent scaling
    allow(Docker::Container).to receive(:get)
    allow(Docker::Container).to receive(:create).and_return(image)
	  Fabricate :pea, app: app
    request = double('request', host: 'fabricated.vcap.me', path: '/somewhere')
    redirect = Peas.proxy request
    expect(redirect.to_s).to eq 'http://localhost:45617/somewhere'
  end

  it 'should not forward if the app has no web containers' do
    request = double('request', host: 'fabricated.vcap.me', path: '/somewhere')
    redirect = Peas.proxy request
    expect(redirect).to eq false
  end

end
