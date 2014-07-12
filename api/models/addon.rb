# Services like Postgres, Redis, etc
class Addon
  include Mongoid::Document

  # Eg; postgres, redis, mongodb, memcache
  # See lib/services or Setting.available_services() for valid types
  field :type

  # How to connect to the specific instance of this service
  # Eg; mongodb://username:password@host:port/database
  field :uri

  belongs_to :app

  def addon_config_key
    "#{type.upcase}_URI"
  end

  after_create do |addon|
    # Add the addons URI to the app's config
    addon.app.config_update(addon_config_key => addon.uri)
  end

  after_destroy do |addon|
    # Add the addons URI to the app's config
    addon.app.config_delete addon_config_key
  end
end
