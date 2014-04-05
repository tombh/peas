module Peas
  def self.proxy request
    if request.host =~ %r{\.#{Peas.domain.gsub('.', '\.')}$}
      app_name = request.host.split('.').first
      app = App.where(name: app_name).first
      random_web_pea = Pea.where(app: app).where(process_type: 'web').to_a.sample
      forwarding_address = "http://#{random_web_pea.host}:#{random_web_pea.port}#{request.path}"
      Application.logger.info "Proxying request to: #{forwarding_address}"
      URI.parse forwarding_address
    end
  end
end