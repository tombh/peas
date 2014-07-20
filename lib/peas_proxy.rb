module Peas
  def self.proxy(request)
    domain = Peas.host
    if request.host =~ /\.#{domain.gsub('.', '\.')}$/
      app_name = request.host.split('.').first
      app = App.where(name: app_name).first
      random_web_pea = Pea.where(app: app).where(process_type: 'web').to_a.sample
      return false if random_web_pea.nil?
      forwarding_address = "http://#{random_web_pea.pod.hostname}:#{random_web_pea.port}#{request.path}"
      API.logger.info "Proxying request to: #{forwarding_address}"
      URI.parse forwarding_address
    end
  end
end
