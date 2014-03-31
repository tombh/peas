class App
  include Mongoid::Document
  field :name, type: String
  has_one :user, as: :owner
end