class Git
  def self.sh cmd
    `#{cmd}`.strip
  end

  def self.root_path
    sh 'git rev-parse --show-toplevel'
  end

  def self.remote
    sh 'git config --get remote.origin.url'
  end

  def self.first_sha
    sh 'git rev-list --max-parents=0 HEAD'
  end
end