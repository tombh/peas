module Peas
  def self.root
    File.dirname __FILE__
  end
end

$LOAD_PATH.unshift(File.join(Peas.root, 'app'))
$LOAD_PATH.unshift(Peas.root)

require 'config/environment'

run Peas::API
