class Pod
  include Mongoid::Document
  include Peas::ModelWorker

  # The hostname of the machine upon which the Pod DinD container resides. This allows peas to be
  # arbitrarily distributed across multiple machines in a cluster. WOW SUCH ELASTIC
  field :hostname

  has_many :peas

  validates_presence_of :hostname

  # Find the best pod to add a container to
  def self.optimal_pod
    Pod.all.sort_by { |pod| pod.peas.count }.first
  end

  def to_s
    "#{hostname}_pod"
  end

  # If this is a default standalone instance of Peas (where it functions as both the controller and a pod), then make
  # sure a pod model object exists to represent the default pod. A pod stub. This could be a dockerless pod if running
  # without Docker-in-Docker in a dev environment.
  def self.create_stub
    if ENV['PEAS_API_LISTENING'] == 'true' && Peas.controller? && Peas.pod? && Pod.count == 0
      Peas.logger.info "Creating Pod stub"
      Pod.create! hostname: 'localhost'
    end
  end
end
