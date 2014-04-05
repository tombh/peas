# An individual docker container
class Pea
  include Mongoid::Document
  field :port, type: String
  field :docker_id, type: String
  belongs_to :app
  validates_presence_of :port, :docker_id, :app
end