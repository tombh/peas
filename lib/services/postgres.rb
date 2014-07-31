require 'lib/services/base'

# Currently only suppoort Postgres >= 9.3

module Peas
  module Services
    class Postgres < ServicesBase

      def connection
        uri_parsed.host
        credentials = {
          host: uri_parsed.host,
          port: uri_parsed.port,
          dbname: 'postgres'
        }
        credentials.merge!(
          user: uri_parsed.user,
          password: uri_parsed.password
        ) if uri_parsed.user
        PG.connect credentials
      end

      def create
        c = connection
        pass = SecureRandom.hex[0..10]
        c.exec "CREATE USER #{user_name} WITH PASSWORD '#{pass}';"
        c.exec "CREATE DATABASE #{instance_name};"
        c.exec "GRANT ALL PRIVILEGES ON DATABASE #{instance_name} TO #{user_name};"
        "postgresql://#{user_name}:#{pass}@#{host_with_port}/#{instance_name}"
      end

      def destroy
        c = connection
        # First make sure all existing connections are closed
        c.exec "REVOKE CONNECT ON DATABASE #{instance_name} FROM public;"
        c.exec "
          SELECT pg_terminate_backend(pid)
          FROM pg_stat_get_activity(NULL::integer)
          WHERE datid=(SELECT oid from pg_database where datname = '#{instance_name}');
        "
        # And now it's safe to do the dropping
        c.exec "DROP DATABASE IF EXISTS #{instance_name}"
        c.exec "DROP ROLE IF EXISTS #{user_name}"
      end
    end
  end
end
