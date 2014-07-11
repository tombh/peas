def image
  double(
    start: double(
      info: { 'id' => rand(10_000_000_000_000).to_s },
      json: {
        'NetworkSettings' => {
          'Ports' =>  {
            '5000' => [{
              'HostPort' => rand(10_000).to_s
            }]
          }
        }
      }
    )
  )
end

# Include this to mock the creation of docker containers
shared_context :docker_creation_mock do
  before :each do
    images = []
    10.times { images << image }
    allow(Docker::Container).to receive(:get)
    allow(Docker::Container).to receive(:create).and_return(*images)
  end
end
