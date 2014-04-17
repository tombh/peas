# Include this to mock the creation of docker containers
shared_context :docker_creation_mock do
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
  before :each do
    allow(Docker::Container).to receive(:get)
    allow(Docker::Container).to receive(:create).and_return(image)
  end
end