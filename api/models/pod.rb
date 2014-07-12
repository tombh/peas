class Pod
  include Mongoid::Document
  include Peas::ModelWorker

  # The ID of the Docker-in-Docker container. Or 'dockerless_pod' if running in development.
  field :docker_id

  # The hostname of the machine upon which the Pod DinD container resides. This allows peas to be
  # arbitrarily distributed across multiple machines in a cluster. WOW SUCH ELASTIC
  field :hostname

  has_many :peas

  # Find the best pod to add a container to
  def self.optimal_pod
    Pod.all.sort_by { |pod| pod.peas.count }.first.docker_id
  end

  # If this is a default standalone instance of Peas (where it functions as both the controller and a pod), then make
  # sure a pod model object exists to represent the default pod. A pod stub. This could be a 'dockerless_pod' if running
  # without Docker-in-Docker in dev environment.
  def self.create_stub
    if Peas.controller? && Peas.pod?
      if Pod.count == 0
        Pod.create docker_id: Peas.current_docker_host_id, hostname: 'localhost'
      end
    end
  end
end
