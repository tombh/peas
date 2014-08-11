module Peas
  class GitSSH
    AUTHORIZED_KEYS_PATH = '/home/git/.ssh/authorized_keys'

    class << self
      # Add an SSH public key to the `.authorized_keys` file
      # `key` An SSH public key
      # TODO: Restrict the repos to which a user can push
      def add_key(key)
        # Don't add the key twice
        return unless File.open(AUTHORIZED_KEYS_PATH) { |f| f.grep(/#{key}/) }.length == 0

        # 'command=' is a syntax specific to SSH. It allows you to run an arbitrary command as soon as a use logs in
        # key_options = "command=\"#{Peas.root}/bin/git_ssh_forced_command\"," \
        #   'no-agent-forwarding,no-pty,no-user-rc,no-X11-forwarding,no-port-forwarding'

        # Append the key with the forced command above
        File.open(AUTHORIZED_KEYS_PATH, 'a') { |f| f.puts "#{key}" }
      end
    end
  end
end
