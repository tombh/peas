# Global Peas settings
class Setting
  include Mongoid::Document

  # List of all the settings that Peas uses
  DEFAULT_KEYS = [
    :domain
  ]

  field :key, type: String
  field :value, type: String

  validates_presence_of :key, :value
  validates_uniqueness_of :key
end
