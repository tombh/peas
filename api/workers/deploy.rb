class DeployWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(first_sha)
    app = App.where(first_sha: first_sha).first
    store output: "Starting deploy of #{app.name}"
  	IO.popen("bin/buildstep.sh #{app.name} #{app.remote}", chdir: Peas.root) do |data|
  	  while line = data.gets
        if line =~ /docker.sock: permission denied/
          line = """The user running Peas does not have permission to use docker. You most likely need to add \
your user to the docker group, eg' \`gpasswd -a <username> docker\`. And remember to login and out to enable the \
new group."""
        end
  	    store output: line
  	  end
    end
    output = retrieve :output
  end
end