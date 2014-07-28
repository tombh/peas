def format_settings(hash)
  puts "Available settings"
  puts ''
  hash.each do |type, settings|
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
          domain = "http://#{domain}" unless domain.start_with? 'http://'
          # Update Git config
          Git.sh "git config peas.domain #{domain}"
          # Update file
          content = Peas.config.merge('domain' => domain).to_json
          File.open(Peas.config_file, 'w+') { |f| f.write(content) }
          @api = API.new # Refresh settings from git/file because there's a new domain URI
        end
        @api.request(:put, '/admin/settings', args[0] => args[1]) { |response| format_settings response }
      else
        @api.request(:get, '/admin/settings') { |response| format_settings response }
      end
    end
  end
end
