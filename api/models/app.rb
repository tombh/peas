class App
  include Mongoid::Document
  include WorkerHelper

  field :first_sha, type: String
  field :remote, type: String
  field :name, type: String
  has_many :peas
  validates_presence_of :first_sha, :remote, :name
  validates_uniqueness_of :first_sha, :name

  # Convert a Git remote URI to an app name usable in subdomains and by docker.
  # Eg; 'git@github.com:owner/repo_name.git' becomes 'repo_name'
  def self.remote_to_name remote
    URI.parse(remote.gsub(':', '/')).path.split('/')[-1].gsub('.git', '')
  end

  # Fetch the latest code, create an image and fire up the necessary containers to make an app
  # pubicly accessible
  def deploy
    worker :build do
      if peas.count == 0
        worker :scale, {web: 1} do
          broadcast
          broadcast "        Deployed to http://#{name}.#{Peas.domain}"
        end
      end
    end
  end

  # Create a docker image using the Buildstep container
  def build
    stream_sh "bin/buildstep.sh #{name} #{remote}"
  end

  # Given a hash of processes like {web: 2, worker: 1} create and/or destroy the necessary
  # containers.
  # TODO: calculate the differences rather than blanket destroy everything!
  def scale processes
    # Destroy all existing containers
    peas.destroy_all
    # Respawn all needed containers
    processes.each do |process_type, quantity|
      quantity.to_i.times do |i|
        broadcast "Scaling process '#{process_type}:#{i+1}'"
        Pea.create!(
          app: self,
          process_type: process_type,
          host: 'localhost'
        )
      end
    end
  end

end