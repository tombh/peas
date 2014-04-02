class Git
  def intialize
    @root = root_path
  end

  def sh cmd
    `#{cmd}`.strip
  end

  def root_path
    sh 'git rev-parse --show-toplevel'
  end

  def remote
    sh 'git config --get remote.origin.url'
  end

  def first_sha
    sh 'git rev-list --max-parents=0 HEAD'
  end
end