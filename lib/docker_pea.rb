# Convenience class to interact with individual peas (Docker containers running PaaS apps)
class DockerPea

  def initialize docker_id
    version_check
    @container = Docker::Container.get(docker_id)
  end

  # Issue a warning if the host's version of Docker is newer than the version Peas is tested against
  def version_check
    if Gem::Version.new(Docker.version['Version']) > Gem::Version.new(Peas::DOCKER_VERSION)
      Peas::Application.logger.warning "Using version #{Docker.version['Version']} of Docker \
        which is newer than the latest version Peas has been tested with (#{Peas::DOCKER_VERSION})"
    end
  end

  # Run a container with a Peas app using the specified process type
  def self.run image, process_type
    container = Docker::Container.create(
      'Cmd' => ['/bin/bash', '-c', "/start #{process_type}"],
      'Image' => image,
      'Env' => 'PORT=5000',
      'ExposedPorts' => {
        '5000' => {}
      }
    ).start(
      'PublishAllPorts' => 'true'
    )
    DockerPea.new container.info['id']
  end

  def docker
    @container
  end

  # Get the current app container's id
  def id
    @container.info['id']
  end

  # Get the current app container's port
  def port
    @container.json['NetworkSettings']['Ports']['5000'].first['HostPort']
  end

  # Kill a running app container
  def kill
    if running?
      @container.kill
    else
      true
    end
  end

  # Return whether an app container is running or not
  def running?
    @container.json['State']['Running']
  end
end