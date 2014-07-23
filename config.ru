ENV['PEAS_API'] = 'true'
require './config/boot'

use Peas::Proxy
run Peas::API
