ENV['RACK_ENV'] ||= "test"

module Peas
  def self.root
    File.join(File.dirname(__FILE__), "../")
  end
  def self.environment
  	ENV['RACK_ENV']
  end
  def self.domain
  	'vcap.me'
  end
end

$LOAD_PATH.unshift(Peas.root)

require 'config/boot'
