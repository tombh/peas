require 'open-uri'

# An app, as you might guess, represents an application. Like a Rails, Django or Wordpress app.
class App
  include Mongoid::Document
  include Peas::ModelWorker

  GIT_RECEIVER_PATH = File.expand_path "#{Peas.root}/bin/git_receiver"

  # The primary key for the app.
  field :name, type: String

  # Environment variables such as a database URI, etc
  field :config, type: Hash, default: {}

  # Peas are needed to actually run the app, such as web and worker processes
  has_many :peas, dependent: :destroy

  # Addons are instances of services like redis, postgres, etc
  has_many :addons, dependent: :destroy

  # Validations
  validates_uniqueness_of :name

  after_create do |app|
    app.create_local_repo
    app.create_capped_collection
    app.create_addons
  end

  before_destroy do |app|
    # Remove the capped collection containing the app's logs
    app.logs_collection.drop

    # Destroy any services being used by the app
    app.addons.each do |addon|
      "Peas::Services::#{addon.type.capitalize}".constantize.new(app).destroy_instance
    end

    app.remove_local_repo
  end

  # Create a capped collection for the logs.
  # Capped collections are of a fixed size (both by rows and memory) and circular, ie; old rows
  # are deleted to make place for new rows when the collection reaches any of its limits.
  def create_capped_collection
    Mongoid::Sessions.default.command(
      create: "#{_id}_logs",
      capped: true,
      size: 1_000_000, # max physical size of 1MB
      max: 2000 # max number of docuemnts
    )
  end

  # Create instances of the available services (like redis or postgres) for the app to use
  def create_addons
    Peas.enabled_services.each do |service|
      "Peas::Services::#{service.capitalize}".constantize.new(self).create_instance
    end
  end

  # Create a unique name given a string as a muse
  def self.divine_name(muse)
    muse = hipster_word if muse.blank?
    muse.gsub!(/[^0-9a-z-]/i, '')
    if App.where(name: muse).count > 0
      "#{hipster_adverb}-#{muse}"
    else
      muse
    end
  end

  # Generate a random word
  def self.hipster_word
    open('http://randomword.setgetgo.com/get.php').read.strip
  end

  # Generate a random hipster adverb
  def self.hipster_adverb
    File.open("#{Peas.root}/lib/adverbs.txt").each_line.to_a.sample.strip
  end

  # The canonical Git remote URI for pushing/deploying
  def remote_uri
    # If we're running inside a Docker-in-Docker container
    if Peas::DIND
      if ENV['GIT_PORT'] != '22'
        "ssh://git@#{Peas.host}:#{ENV['GIT_PORT']}/~/#{name}.git"
      else
        "git@#{Peas.host}:#{name}.git"
      end
    # If we're running in development
    else
      local_repo_path
    end
  end

  # The local path on the filesystem where the app's Git repo lives
  def local_repo_path
    "#{Peas::APP_REPOS_PATH}/#{name}.git"
  end

  # Create a bare Git repo ready to receive git pushes to trigger deploys
  def create_local_repo
    Peas.sh "mkdir -p #{local_repo_path}", user: Peas::GIT_USER
    Peas.sh "cd #{local_repo_path} && git init --bare", user: Peas::GIT_USER
    create_prereceive_hook
  end

  # Create a pre-receive hook in the app's Git repo that will trigger Peas' deploy process
  # TODO: Consider putting Peas.root in an ENV variable, so that the pre-receive hook still works if the Peas code is
  # moved somewhere else on the system.
  def create_prereceive_hook
    hook_path = "#{local_repo_path}/hooks/pre-receive"
    hook_code = "#!/bin/bash\nexport PEAS_ENV=#{ENV['PEAS_ENV']}\ncd #{Peas.root}\ncat | #{GIT_RECEIVER_PATH} #{name}\n"
    Peas.sh "echo '#{hook_code}' > #{hook_path}", user: Peas::GIT_USER
    Peas.sh "chmod +x #{hook_path}", user: Peas::GIT_USER
  end

  def remove_local_repo
    return unless File.exist? local_repo_path
    unless Dir.entries(local_repo_path).include? 'hooks'
      raise Peas::PeasError, "Refusing to `rm -rf` folder that doesn't look like a Git repo"
    end
    Peas.sh "rm -rf #{local_repo_path}", user: Peas::GIT_USER
  end

  # Pretty arrow. Same as used in Heroku buildpacks
  def arrow
    '-----> '
  end

  # Represent the app's current scaling profile as a hash
  def process_types
    profile = {}
    peas.each do |pea|
      if profile.key? pea.process_type
        profile[pea.process_type] += 1
      else
        profile[pea.process_type] = 1
      end
    end
    profile
  end

  # Restart all the app's processes. Useful in cases such as updating environment variables
  def restart
    broadcast "Restarting all processes..." if @current_job
    scale process_types
  end

  # Fetch the latest code, create an image and fire up the necessary containers to make an app
  # pubicly accessible
  #
  # `new_revision` The SHA1 hash for the commit to build from. Provided by Git pre-recieve hook.
  def deploy(new_revision)
    @new_revision = new_revision
    broadcast "Deploying #{name}" if @current_job
    worker.build(new_revision) do
      if peas.count == 0
        scaling_profile = { web: 1 }
      else
        scaling_profile = process_types
      end
      broadcast
      worker.scale scaling_profile, :deploy do
        broadcast
        broadcast "       Deployed to http://#{name}.#{Peas.domain.gsub('http://', '')}"
      end
    end
  end

  # Create a Docker image using the Buildstep container.
  # The resultant image can be fired up as a new Docker containers instantly to run multiple
  # process types.
  #
  # `new_revision` The SHA1 hash for the commit to build from. Provided by Git pre-recieve hook.
  #
  # To find out more about Buildstep see: https://github.com/progrium/buildstep
  def build(new_revision)
    builder = Peas::Builder.new self, new_revision

    # Prepare the repo for Buildstep.
    builder.tar_repo

    # Create a container that builds the app
    builder.create_build_container

    # Build the app and commit an image
    builder.create_app_image
  end

  # Given a hash of processes like `{web: 2, worker: 1}` create and/or destroy the necessary
  # containers.
  # TODO: when not part of a deployment calculate the differences rather than blanket destroy
  # everything!
  def scale(processes, deploy = false)
    # Destroy all existing containers
    peas.destroy_all
    # Respawn all needed containers
    processes.each do |process_type, quantity|
      quantity.to_i.times do |i|
        broadcast "#{arrow if deploy}Scaling process '#{process_type}:#{i + 1}'" if @current_job
        Pea.spawn(
          {
            app: self,
            process_type: process_type
          },
          block_until_complete: true,
          parent_job_id: @parent_job
        )
      end
    end
  end

  # Convert config into a string with equals signs between keys and values.
  # Eg; { 'foo': 'bar' } => 'foo=bar'
  def config_for_docker
    result = []
    config.each do |k, v|
      result << "#{k}=#{v}"
    end
    result
  end

  # Update config variables
  def config_update(hash)
    # Merge the new config with a hashed version of the existing config
    self.config = config.merge! hash
    save!
    worker(block_until_complete: true).restart
    config
  end

  # Delete config variables
  def config_delete(keys)
    keys = [keys] unless keys.is_a? Array
    keys.each do |key|
      config.delete key
    end
    save!
    restart
    config
  end

  # Return a connection to the capped collection that stores all the logs for this app
  def logs_collection
    Mongoid::Sessions.default["#{_id}_logs"]
  end

  # Return a list of the most recent log lines for the app
  def recent_logs(lines = 100)
    logs_collection.find.limit(lines).to_a.map { |line| line['line'] }
  end

  # Log any activity for this app
  def log(logs, from = 'general', _level = :info)
    logs = logs.to_s
    logs.lines.each do |line|
      line.strip!
      next if line =~ /^\s*$/ # Is nothing but whitespace
      line = "#{DateTime.now} app[#{from}]: #{line}"
      logs_collection.insert(line: line)
    end
  end
end
