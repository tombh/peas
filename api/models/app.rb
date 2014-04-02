class App
  include Mongoid::Document
  field :first_sha, type: String
  field :remote, type: String
  field :name, type: String
  validates_presence_of :first_sha, :remote, :name
  validates_uniqueness_of :first_sha, :name

  # Convert a Git remote URI to an app name usable in subdomains and by docker.
  # Eg; 'git@github.com:owner/repo_name.git' becomes 'repo_name'
  def self.remote_to_name remote
    URI.parse(remote.gsub(':', '/')).path.split('/')[-1].gsub('.git', '')
  end
end