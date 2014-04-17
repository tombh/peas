class App
  include Mongoid::Document
  include WorkerHelper

  field :first_sha, type: String
  field :remote, type: String
  field :name, type: String
  has_many :peas
  validates_presence_of :first_sha, :remote, :name
  validates_uniqueness_of :first_sha, :name

  def arrow
    '-----> '
  end

  # Convert a Git remote URI to an app name usable in subdomains and by docker.
  # Eg; 'git@github.com:owner/repo_name.git' becomes 'repo_name'
  def self.remote_to_name remote
    URI.parse(remote.gsub(':', '/')).path.split('/')[-1].gsub('.git', '')
  end

  # Represent the apps current scaling profile as a hash
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

  # Create a docker image using the Buildstep container
  def build
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

    broadcast "#{arrow}Adding repo to Buildstep"
    # Tar the repo to make moving it around more efficient
    FileUtils.mkdir_p Peas::TMP_TARS
    tmp_tar_path = "#{Peas::TMP_TARS}/#{name}.tgz"
    sh "cd #{tmp_repo_path} && tar --exclude='.git' -zcf #{tmp_tar_path} ."

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
        'Cmd' => [
          '/bin/bash',
          '-c',
          "mkdir -p /app && tar -xf #{tmp_tar_path} -C /app && /build/builder"
        ]
      },
      conn_interactive,
    )
    building = builder.start(
      # Mount the host filesystem's /tmp folder to the same place on Buildstep
      'Binds' => ['/tmp:/tmp']
    )
    build_error = false
    building.attach do |stream, chunk|
      build_error = chunk if stream == :stderr
      broadcast chunk
    end

    if builder.wait['StatusCode'] == 0
      builder.commit 'repo' => name
    end

    # Make sure to clean up after ourselves
    builder.kill
    builder.delete force: true

    raise build_error.strip if build_error
  end

  # Given a hash of processes like {web: 2, worker: 1} create and/or destroy the necessary
  # containers.
  # TODO: calculate the differences when destroy is false rather than blanket destroy everything!
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

end