module Peas
  # The port for Peas' Switchboard socket server
  SWITCHBOARD_PORT = ENV['SWITCHBOARD_PORT'] || 9345

  def self.config_file
    "#{ENV['HOME']}/.peas"
  end

  # Read JSON config from file
  def self.config
    file = File.open config_file, "a+"
    contents = file.read
    contents = '{}' if contents == ''
    JSON.parse contents
  end

  # Hierarchy of sources for the Peas API domain
  def self.api_domain
    domain =
    if ENV['PEAS_API_ENDPOINT']
      ENV['PEAS_API_ENDPOINT']
    elsif Peas.config['domain']
      Peas.config['domain']
    else
      'vcap.me:4000'
    end
    unless domain[/\Ahttp:\/\//] || domain[/\Ahttps:\/\//]
      "http://#{domain}"
    else
      domain
    end
  end

  def self.host
    URI.parse(Peas.api_domain).host
  end

  def self.error_message(string)
    puts string.color(:red)
  end

  def self.warning_message(string)
    puts string.color(:magenta)
  end
end
