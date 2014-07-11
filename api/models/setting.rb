# Global Pea settings
class Setting
  include Mongoid::Document
  field :key, type: String
  field :value, type: String
  validates_presence_of :key, :value
  validates_uniqueness_of :key
end
