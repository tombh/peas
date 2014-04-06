module Peas
  def self.config
    file = File.open config_file, "a+"
    contents = file.read
    contents = '{}' if contents == ''
    JSON.parse contents
  end

  def self.config_file
  	"#{ENV['HOME']}/.peas"
  end
end