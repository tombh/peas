module Peas

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
    if ENV['PEAS_API_ENDPOINT']
      ENV['PEAS_API_ENDPOINT']
    elsif Peas.config['domain']
      Peas.config['domain']
    else
      'localhost:4000'
    end
  end

end