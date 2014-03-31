ENV['RACK_ENV'] ||= "test"

module Peas
  def self.root
    File.join(File.dirname(__FILE__), "../")
  end
end

$LOAD_PATH.unshift(Peas.root)
$LOAD_PATH.unshift(File.join(Peas.root, 'app'))

require 'config/boot'
