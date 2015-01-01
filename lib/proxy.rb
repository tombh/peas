require "net/http"
require "enumerator"

module Peas
  class Proxy
    def call(env)
      req = Rack::Request.new(env)
      method = req.request_method.downcase
      method[0..0] = method[0..0].upcase

      uri = find_destination(req)
      return [200, {}, ["Peas has no application at this address"]] unless uri

      sub_request = Net::HTTP.const_get(method).new("#{uri.path}#{'?' if uri.query}#{uri.query}")

      if sub_request.request_body_permitted? && req.body
        sub_request.body_stream = req.body
        sub_request.content_length = req.content_length
        sub_request.content_type = req.content_type
      end

      sub_request["X-Forwarded-For"] = (req.env["X-Forwarded-For"].to_s.split(/, +/) + [req.env['REMOTE_ADDR']]).join(", ")
      sub_request["Accept-Encoding"] = req.accept_encoding
      sub_request["Referer"] = req.referer

      begin
        sub_response = Net::HTTP.start(uri.host, uri.port) do |http|
          http.request(sub_request)
        end
      rescue EOFError
        Peas::API.logger.error @random_web_pea.app.recent_logs(10)
        return [
          500,
          {},
          ["The application '#{@random_web_pea.app.name}' didn't respond. Please check the logs and try again."]
        ]
      end

      headers = {}
      sub_response.each_header do |k, v|
        headers[k] = v unless k.to_s =~ /cookie|content-length|transfer-encoding/i
      end

      [sub_response.code.to_i, headers, [sub_response.read_body]]
    end

    def find_destination(req)
      peas_part = Peas.host.split('.').first # Eg; 'peas' from 'peas.io'
      req_part = req.host.split('.').first # Eg; 'appname' from 'appname.peas.io'
      return false if peas_part == req_part # If there's no subdomain
      app_name = req_part
      app = App.where(name: app_name).first
      @random_web_pea = Pea.where(app: app).where(process_type: 'web').to_a.sample
      return false if @random_web_pea.nil?
      forwarding_address = "http://#{@random_web_pea.pod.hostname}:#{@random_web_pea.port}#{req.path}"
      Peas.logger.info "Proxying request to: #{forwarding_address}"
      URI.parse forwarding_address
    end
  end
end
