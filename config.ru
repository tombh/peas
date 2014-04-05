require './config/environment'

use Rack::Proxy do |req|
  if req.host =~ %r{peas.vcap.me}
    URI.parse("http://localhost:49155/#{req.path}")
  end
end

run Peas::Application
