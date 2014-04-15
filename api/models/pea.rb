# An individual docker container
class Pea
  include Mongoid::Document
  field :port, type: String
  field :docker_id, type: String
  field :process_type, type: String
  field :host, type: String
  belongs_to :app
  validates_presence_of :port, :docker_id, :app

  def initialize(attrs = nil)
    super
    @container = get_docker_container
  end

  # Before persisting a pea create a running container with the parent app using the specified process type
  before_validation do |pea|
    if new_record?
      container = Docker::Container.create(
        'Cmd' => ['/bin/bash', '-c', "/start #{pea.process_type}"],
        'Image' => app.name,
        'Env' => 'PORT=5000',
        'ExposedPorts' => {
          '5000' => {}
        }
      ).start(
        'PublishAllPorts' => 'true'
      )
      pea.docker_id = container.info['id']
      pea.port = container.json['NetworkSettings']['Ports']['5000'].first['HostPort']
      get_docker_container
    end
  end

  # Before removing a pea from the database kill and remove the relevant app container
  before_destroy do
    get_docker_container
    if docker
      docker.kill
      docker.delete
    end
  end

  def get_docker_container
    @container = Docker::Container.get(docker_id) if docker_id
  end

  def docker
    @container
  end

  # Return whether an app container is running or not
  def running?
    @container.json['State']['Running']
  end
end