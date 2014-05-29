# An app, as you might guess, represents an application. Like a Rails, Django or Wordpress app.
class App
  include Mongoid::Document
  include WorkerHelper

  # The first SHA1 hash of the repo's commit history is used as a fingerprint tying the repo to an
  # app
  field :first_sha, type: String

  # The Git remote for the app. Currently only remote URIs supported. Plan to support local paths
  # as well
  field :remote, type: String

  # The human-readable name for the app. Based on the remote URI. See App.remote_to_name
  field :name, type: String

  # Environment variables such as a database URI, etc
  field :config, type: Array, default: []

  # Peas are needed to actually run the app, suh as web and worker processes
  has_many :peas

  # Validations
  validates_presence_of :first_sha, :remote, :name
  validates_uniqueness_of :first_sha, :name

  # Pretty arrow. Same as used in Heroku buildpacks
  def arrow
    '-----> '
  end

  # Convert a Git remote URI to an app name usable in subdomains and by docker.
  # Eg; 'git@github.com:owner/repo_name.git' becomes 'repo_name'
  def self.remote_to_name remote
    URI.parse(remote.gsub(':', '/')).path.split('/')[-1].gsub('.git', '')
  end

  # Represent the app's current scaling profile as a hash
  def process_types
    profile = {}
    peas.each do |pea|
      if profile.has_key? pea.process_type
        profile[pea.process_type] += 1
      else
        profile[pea.process_type] = 1
      end
    end
    profile
  end

  # Restart all the app's processes. Useful in cases such as updating environment variables
  def restart
    scale process_types
  end

  # Fetch the latest code, create an image and fire up the necessary containers to make an app
  # pubicly accessible
  def deploy
    worker :build do
      if peas.count == 0
        scaling_profile = {web: 1}
      else
        scaling_profile = process_types
      end
      broadcast
      worker :scale, scaling_profile, :deploy do
        broadcast
        broadcast "       Deployed to http://#{name}.#{Peas.domain}"
      end
    end
  end

  # Create a Docker image using the Buildstep container.
  # The resultant image can be fired up as a new Docker containers instantly to run multiple
  # process types.
  # To find out more about Buildstep see: https://github.com/progrium/buildstep
  def build

    # Prepare the repo for Buildstep. Keeping it in a separate function keeps build() simpler and
    # helps with testing
    _fetch_and_tar_repo

    # Create a new Docker image based on progrium/buildstep with the repo placed at /app
    # There's an issue with Excon's buffer so we need to manually lower the size of the chunks to
    # get a more interactive-style attachment.
    # Follow the issue here: https://github.com/swipely/docker-api/issues/77
    conn_interactive = Docker::Connection.new(Peas::DOCKER_SOCKET, {:chunk_size => 1})
    builder = Docker::Container.create(
      {
        'Image' => 'progrium/buildstep',
        'Volumes' => {
          '/tmp' => {}
        },
        'Env' => config.join(' '),
        'Cmd' => [
          '/bin/bash',
          '-c',
          "mkdir -p /app && tar -xf #{@tmp_tar_path} -C /app && /build/builder"
        ]
      },
      conn_interactive,
    )
    building = builder.start(
      # Mount the host filesystem's /tmp folder to the same place on Buildstep
      'Binds' => ['/tmp:/tmp']
    )

    # Stream the output of the the buildstep process
    build_error = false
    last_message = nil
    building.attach do |stream, chunk|
      # Save the error for later, because we still need to clean up the container
      build_error = chunk if stream == :stderr
      last_message = chunk # In case error isn't sent through :stderr
      broadcast chunk
    end

    # Commit the container with the newly built app as a new image named after the app
    if builder.wait['StatusCode'] == 0
      builder.commit 'repo' => name
    else
      build_error = "Buildstep failed with non-zero exit status. " +
        "Error message was: '#{build_error}'. " +
        "Last message was: '#{last_message}'."
    end

    # Keep a copy of the build container's details
    builder_json = builder.json

    # Make sure to clean up after ourselves
    begin
      builder.kill
      builder.delete force: true
    rescue Docker::Error::NotFoundError
    end

    raise build_error.strip if build_error

    builder_json
  end

  def _fetch_and_tar_repo
    # First we need an up to date version of the repo
    FileUtils.mkdir_p Peas::TMP_REPOS
    tmp_repo_path = "#{Peas::TMP_REPOS}/#{name}"

    broadcast "#{arrow}Fetching #{remote}"
    if File.directory? tmp_repo_path
      # Clone if we don't have an existing version
      sh "cd #{tmp_repo_path} && git pull #{remote}"
    else
      # Just update the changes if there's an existing version of the repo
      sh "git clone --depth 1 #{remote} #{tmp_repo_path}"
    end

    # Tar the repo to make moving it around more efficient
    broadcast "#{arrow}Tarring repo"
    FileUtils.mkdir_p Peas::TMP_TARS
    @tmp_tar_path = "#{Peas::TMP_TARS}/#{name}.tgz"
    sh "cd #{tmp_repo_path} && tar --exclude='.git' -zcf #{@tmp_tar_path} ."
  end

  # Given a hash of processes like {web: 2, worker: 1} create and/or destroy the necessary
  # containers.
  # TODO: when not part of a deployment calculate the differences rather than blanket destroy
  # everything!
  def scale processes, deploy = false
    # Destroy all existing containers
    peas.destroy_all
    # Respawn all needed containers
    processes.each do |process_type, quantity|
      quantity.to_i.times do |i|
        broadcast "#{arrow if deploy}Scaling process '#{process_type}:#{i+1}'"
        Pea.create!(
          app: self,
          process_type: process_type,
          host: 'localhost'
        )
      end
    end
  end

  # Represent the app's config as a hash
  def config_hash
    hashed_config = {}
    config.map{|c| hashed_config.merge! c}
    return hashed_config
  end
end