class App
  include Mongoid::Document
  field :name, type: String
  validates_presence_of :name
end