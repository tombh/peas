class Pod
  include Mongoid::Document
  include ModelWorker

  # The ID of the Docker-in-Docker container. Can be nil if running in development.
  field :docker_id

  has_many :peas

  # Find the best pod to add a container to
  def self.optimal_pod
    lowest_population = Pod.all.map{|p| p.peas.count}.min
    Pod.where(:peas.length => lowest_population).first
  end
end
