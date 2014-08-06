require "addressable/uri"

class Git
  def self.sh(cmd)
    `#{cmd}`.strip
  end

  def self.root_path
    sh 'git rev-parse --show-toplevel'
  end

  def self.remote(remote = 'peas')
    sh "git config --get remote.#{remote}.url"
  end

  def self.add_remote(remote)
    sh "git remote add peas #{remote}"
  end

  def self.name_from_remote(remote_uri = nil)
    remote_uri = remote unless remote_uri
    parts = Addressable::URI.parse remote_uri
    parts.path.gsub('.git', '')
  end
end
