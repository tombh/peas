class Pod
  include Mongoid::Document
  include ModelWorker

  # The ID of the Docker-in-Docker container. Can be nil if running in development.
  field :docker_id

  has_many :peas

  # Find the best pod to add a container to
  def self.optimal_pod
    Pod.all.sort_by{|pod| pod.peas.count}.first.docker_id
  end
end
