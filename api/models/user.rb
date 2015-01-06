# Peas user
class User
  include Mongoid::Document

  # User name
  field :username, type: String
  # OpenSSH public key
  field :public_key, type: String
  # Peas generated API key to grant authorisation to use the API
  field :api_key, type: String
  # Temporary field to hold string for SSL key signing
  field :signme, type: String

  validates_uniqueness_of :username, :api_key

  # SSH keys can have various parts, we just need the long key
  before_save do |doc|
    if doc[:public_key]
      doc[:public_key] = doc[:public_key].split(' ').max_by(&:length)
    end
  end
end
