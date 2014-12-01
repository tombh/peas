require './config/boot'

run Peas::Proxy if ENV['PEAS_PROXY_LISTENING'] == 'true'
run Peas::API if ENV['PEAS_API_LISTENING'] == 'true'
