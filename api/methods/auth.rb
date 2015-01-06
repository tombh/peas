module Peas
  class API < Grape::API
    # /auth
    resource :auth do
      # POST /auth/request
      desc "Request authentication with username and public key, returns document to sign"
      params do
        requires :username, type: String, desc: "Username"
        requires :public_key, type: String, desc: "User's SSH public key"
      end
      post :request do
        response = {}
        user = User.where username: params[:username]
        if user.length == 0
          if User.count == 0
            # Automatically add the user if they are the first in the DB
            user = User.create! username: params[:username], public_key: params[:public_key]
            response[:user_added] = [user.username, user.public_key]
          else
            status 400
            return respond 'User does not exist, ask admin user to add you', :error
          end
        end
        user.signme = SecureRandom.urlsafe_base64 64
        user.save!
        response[:sign] = user.signme
        respond response
      end

      # POST /auth/verify
      desc "Verify a signed document. Returns a new API key"
      params do
        requires :username, type: String, desc: "Username"
        requires :signed, type: String, desc: "A OpenSSL signed document"
      end
      post :verify do
        user = User.find_by username: params[:username]
        # Convert the SSH key to an OpenSSL key
        public_key = OpenSSHKeyConverter.decode_pubkey user.public_key
        document = user.signme
        # Confirm that the user signed the doc with the private key that pairs with their public key
        if public_key.verify(OpenSSL::Digest::SHA256.new, params[:signed], document)
          # Issue them an api_key which can be used to access methods on the API
          api_key = SecureRandom.urlsafe_base64 64
          user.api_key = api_key
          user.save!
          return respond api_key: api_key
        else
          status 406
          return respond 'Could not verify signed document', :error
        end
      end
    end
  end
end
