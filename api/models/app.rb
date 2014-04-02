class App
  include Mongoid::Document
  field :name, type: String
  field :repo, type: String
  validates_presence_of :name
end