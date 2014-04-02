class DeployWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(app_name)
  	app = App.where(name: app_name)
  	IO.popen("bin/buildstep #{app.name} #{app.repo}", chdir: Peas.root) do |data|
	  while line = data.gets
	    store output: line
	  end
	end
    output = retrieve :output
  end
end