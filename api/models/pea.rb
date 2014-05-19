# A pea is a core concept for Peas, who would have thought?
#
# A pea is the same as a dyno in the Heroku paradigm. It is a self-contained instance of an
# application with all its dependencies. Most often it will respond to web requests. It is
# perfectly reasonsable for an app to have no more than one pea. A pea is a single Docker container
# that isolates the app's resources from the host machine.
#
# Regardless of the pea's purpose in life it is always passed the environment variable PORT=5000,
# which any web servers used by the app can inherit from. That port is then exposed by Docker to the
# host machine. The global Peas proxy, which could be located on a different machine, can then
# forward any web requests for the app to the relevant Docker container. The exposing of the port is
# done via a kind of port forwarding; the Docker container might expose itself to the host machine
# as port 46517, but then forward incoming connections internally to port 5000.
#
# Peas can just as well have no connection to the web, such as a worker process. A worker process
# runs exactly the same code but will not listen for web requests. Instead it might listen to a
# message queue such as Redis and carry out long-running jobs that might update values in a database
# shared by all peas associated with an app.
class Pea
  include Mongoid::Document

  # The external port used to gain access to the container's internal port 5000. This port value
  # is randomly generated by Docker and is guarenteed not to clash with other ports on the host
  # machine
  field :port, type: String

  # Every pea must have a container, this is the unique Docker ID hash for that container
  field :docker_id, type: String

  # Every pea must have a process type such as 'web', 'worker', etc. Process types are arbitrary,
  # the only criteria is that the process type must exist as a line in the app's Procfile. If an app
  # doesn't have a Procfile in its project root then the Heroku buildpack responsible for building
  # the app will create a Procfile during the build process with default process types.
  field :process_type, type: String

  # The hostname of the machine upon which the Docker container resides. This allows peas to be
  # arbitrarily distributed across multiple machines in a cluster. WOW SUCH ELASTIC
  field :host, type: String

  # A pea must belong to an app
  belongs_to :app

  validates_presence_of :port, :docker_id, :app

  def initialize(attrs = nil)
    super
    @container = get_docker_container
  end

  # Before persisting a pea create a running container with the parent app using the specified
  # process type
  before_validation do |pea|
    pea.spawn_container if new_record?
  end

  # Before removing a pea from the database kill and remove the relevant app container
  before_destroy do
    destroy_container
  end

  # Create the docker container for which this object is a representation
  def spawn_container
    container = Docker::Container.create(
      # `/start` is unique to progrium/buildstep, it brings a process type, such as 'web', to life
      'Cmd' => ['/bin/bash', '-c', "/start #{process_type}"],
      # The base Docker image to use. In this case the prebuilt image created by the buildstep
      # process
      'Image' => app.name,
      # Global environment variables to pass and make available to the app
      'Env' => "PORT=5000 #{app.config.join(' ')}",
      # Expose port 5000 from inside the container to the host machine
      'ExposedPorts' => {
        '5000' => {}
      }
    ).start(
      # Takes each ExposedPort and forwards an external port to it. Eg; 46517 -> 5000
      'PublishAllPorts' => 'true'
    )
    # Get the Docker ID so we can find it later
    self.docker_id = container.info['id']
    # Find the randomly created external port that forwards to the internal 5000 port
    self.port = container.json['NetworkSettings']['Ports']['5000'].first['HostPort']
    save! if !new_record?
    get_docker_container
  end

  # Destroy the pea's container
  def destroy_container
    begin
      get_docker_container
      if docker
        # Stop whatever the container is doing
        docker.kill
        # Remove the container from existence
        docker.delete
      end
    rescue Docker::Error::NotFoundError
      Peas::API.logger.warn "Can't find pea's container, destroying DB object anyway"
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