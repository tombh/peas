require './config/environment'

use Rack::Proxy do |request|
  Peas.proxy request
end

run Peas::Application
