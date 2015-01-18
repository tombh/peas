def format_settings(hash)
  puts "Available settings"
  puts ''
  hash['message'].each do |type, settings|
    puts "#{type.capitalize}:"
    settings.each do |setting, value|
      value = '[unset]' if value == ''
      puts "  #{setting} #{value}"
    end
    puts ''
  end
end

desc "Admin commands"
command :admin do |admin|
  admin.desc 'Set Peas global system settings'
  admin.command :settings do |settings|
    settings.action do |_global_options, _options, args|
      if args.count > 1
        if args.first == 'peas.domain'
          domain = args[1]
          domain = "https://#{domain}" unless domain.start_with? 'https://'
          # Update Git config
          Git.sh "git config peas.domain #{domain}"
          # Update file
          Peas.update_config domain: domain
          @api = API.new # Refresh settings from git/file because there's a new domain URI
        end
        format_settings @api.request(:put, '/admin/settings', { args[0] => args[1] }, true, false)
      else
        format_settings @api.request(:get, '/admin/settings', {}, true, false)
      end
    end
  end

  admin.desc 'Run commands on the Peas Controller'
  admin.long_desc <<-EOF
  For example: peas admin run rake console
  EOF
  admin.command :run do |c|
    c.action do |_global_options, _options, args|
      exit_now!("Please provide a command to run", 1) if args.length == 0
      socket = API.switchboard_connection
      socket.puts "admin_tty"
      tty_command = args.join ' '
      socket.puts tty_command
      API.duplex_socket socket
    end
  end
end
