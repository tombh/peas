# Global Peas settings
# NB the word 'setting' is used here rather than 'config' to differentiate between an individual
# app's config and Peas' global config.
class Setting
  include Mongoid::Document

  # List of all the settings that Peas uses
  DEFAULTS = {
    'peas.domain' => "#{Peas::CONTROLLER_DOMAIN}:#{Peas::API_PORT}"
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

  # Create a token that Switchboard clients can use to authorise to the Switchboard server.
  # Basically, this answers the question of whether a remote pod can access the same DB as that
  # used by the controller.
  # It changes with every controller boot to provide some security through expiration.
  def self.set_switchboard_key
    return unless Peas.controller? # No need to update the key when pods boot
    key = 'peas.switchboard_key'
    value = SecureRandom.urlsafe_base64(64)
    setting = Setting.where key: key
    if setting.count == 1
      setting.first.value = value
      setting.first.save!
    else
      Setting.create key: key, value: value
    end
  end
end
