module Peas
  class GitSSH
    AUTHORIZED_KEYS_PATH = '/home/git/.ssh/authorized_keys'

    class << self
      # Add an SSH public key to SSH server's `authorized_keys` file.
      # `key` An SSH public key
      # TODO: Restrict the repos to which a user can push
      def add_key(key)
        return unless Peas::DIND # When in development git push occurs over local paths
        # Don't add the key twice
        keys = Peas.sh "cat #{AUTHORIZED_KEYS_PATH}", user: Peas::GIT_USER
        return if keys.include? key

        # TODO: add the force command and `git-shell` for security
        # 'command=' is a syntax specific to SSH. It allows you to run an arbitrary command as soon as a user logs in
        # key_options = "command=\"#{Peas.root}/bin/git_ssh_forced_command\"," \
        #   'no-agent-forwarding,no-pty,no-user-rc,no-X11-forwarding,no-port-forwarding'

        # Append the key
        Peas.sh "echo '#{key}' >> #{AUTHORIZED_KEYS_PATH}", user: Peas::GIT_USER
      end
      
      # Remove a given key from SSH's `authorized_keys` file
      # `key` An SSH public key
      def remove_key(key)
        return unless Peas::DIND # When in development git push occurs over local paths
        Peas.sh "sed -i '\\|#{key}|d' #{AUTHORIZED_KEYS_PATH}", user: Peas::GIT_USER
      end
    end
  end
end
