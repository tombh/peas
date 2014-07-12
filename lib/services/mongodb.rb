require 'lib/services/base'

module Peas
  module Services
    class Mongodb < ServicesBase

      def client(command)
        auth = "-u #{uri_parsed.user} -p #{uri_parsed.password}" if uri_parsed.user
        # Make sure the command is all on one line
        command.gsub!(/\s+/, "")
        # Having to use command line at the moment because moped doesn't seem to be able to issue
        # db.addUser() and the mongo-ruby-driver has a dependency mismatch with mongoid's bson gem.
        `mongo #{host_with_port}/#{instance_name} #{auth} --eval "#{command};"`
      end

      def create
        pass = SecureRandom.hex[0..10]
        client "db.addUser({
          user: '#{user_name}',
          pwd: '#{pass}',
          roles: ['readWrite']
        })"
        "mongodb://#{user_name}:#{pass}@#{host_with_port}/#{instance_name}"
      end

      def destroy
        client "db.dropDatabase()"
      end
    end
  end
end
