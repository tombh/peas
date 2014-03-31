class Git
  def intialize
    @root = sh 'git rev-parse --show-toplevel'
  end

  def sh cmd
    `#{cmd}`.strip
  end

  def remote
    sh 'git config --get remote.origin.url'
  end
end