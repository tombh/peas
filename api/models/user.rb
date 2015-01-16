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
  validates_presence_of :username

  before_save do |user|
    if user[:public_key]
      # Add user's full key to SSH's authorized_keys file so that they can git push
      Peas::GitSSH.add_key user[:public_key]
      # SSH keys can have various parts, we just need the long key for the DB
      user[:public_key] = user[:public_key].split(' ').max_by(&:length)
    end
  end

  after_destroy do |user|
    # Remove user's key from SSH's authorized_keys file so they can't git push
    Peas::GitSSH.remove_key user[:public_key]
  end
end
