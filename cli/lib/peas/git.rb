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

  def self.remove_remote(remote = 'peas')
    sh "git remote rm #{remote}"
  end

  def self.name_from_remote(remote_uri = nil)
    remote_uri = remote unless remote_uri
    exit_now! "No Peas remote. I can't figure out what app this is.", 1 if remote_uri == ''
    parts = Addressable::URI.parse remote_uri
    parts.path.split('/').last.gsub('.git', '').downcase
  end
end
