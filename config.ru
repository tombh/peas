ENV['PEAS_API_LISTENING'] = 'true'
require './config/boot'

use Peas::Proxy
run Peas::API
