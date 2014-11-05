# Global Peas settings
# NB the word 'setting' is used here rather than 'config' to differentiate between an individual app's config
# and Peas global config.
class Setting
  include Mongoid::Document

  # List of all the settings that Peas uses
  DEFAULTS = {
    'peas.domain' => "#{Peas::DEFAULT_CONTROLLER_DOMAIN}:#{Peas::DEFAULT_API_PORT}"
  }

  field :key, type: String
  field :value, type: String

  validates_presence_of :key, :value
  validates_uniqueness_of :key

  def self.retrieve(key)
    key = key.to_s
    find_by(key: key).value
  rescue Mongoid::Errors::DocumentNotFound
    # See if setting is in DEFAULTS otherwise return ''
    DEFAULTS.fetch key, ''
  end
end
