def container
  double(
    start: instance_double(Docker::Container),
    info: { 'id' => rand(10_000_000_000_000).to_s },
    json: {
      'NetworkSettings' => {
        'Ports' =>  {
          '5000' => [{
            'HostPort' => rand(10_000).to_s
          }]
        }
      }
    },
    kill: true,
    delete: true
  )
end

# Include this to mock the creation of docker containers
shared_context :docker_creation_mock do
  before :each do
    # Multiple calls to :get and :create each return a new container
    containers = []
    10.times { containers << container }
    allow(Docker::Container).to receive(:get).and_return(*containers)
    allow(Docker::Container).to receive(:create).and_return(*containers)
  end
end
