require './config/boot'

use Rack::Proxy do |request|
  Peas.proxy request
end

run Peas::API
