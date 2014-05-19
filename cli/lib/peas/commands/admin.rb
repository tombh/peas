desc 'Set Peas global settings'
command :settings do |c|
  c.flag 'domain',
    type: String,
    desc: 'The FQDN for the Peas server'
  c.action do |global_options, options, args|
    if options['domain']
      if !options['domain'].start_with? 'http://'
        options['domain'] = "http://#{options['domain']}"
      end
    end
    # Gli seems to provide a String and Symbol key for every option, so the options hash needs
    # de-duplicating
    deduped = {}
    options.each do |k, v|
      deduped[k] = v if k.is_a? String
    end
    # Merge existing settings with current settings
    content = Peas.config.merge(deduped).to_json
    File.open(Peas.config_file, 'w+'){|f| f.write(content) }
    # Save the settings on the server as well
    @api = API.new # Refresh settings from file
    @api.request :put, '/admin/settings', options
    puts "New settings:"
    puts JSON.pretty_generate(Peas.config)
  end
  desc 'Display the current settings'
  c.command :display do |c|
    c.action do |global_options, options, args|
      puts JSON.pretty_generate(Peas.config)
    end
  end
end