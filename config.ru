require './config/boot'

# Unorthodox, but we're using the same config.ru file for two seperate processes
run Peas::Proxy.new if ENV['PEAS_PROXY_LISTENING'] == 'true'
run Peas::API if ENV['PEAS_API_LISTENING'] == 'true'
