module Peas
  class AdminMethods < Grape::API; end
  class API < Grape::API
    helpers do
      def current_settings
        {
          defaults: Setting::DEFAULTS.keys.map { |s|
            { s => Setting.retrieve(s.to_s) }
          }.reduce({}, :update),
          services: Peas.available_services.map { |s|
            { "#{s}.uri" => Setting.retrieve("#{s}.uri") }
          }.reduce({}, :update)
        }
      end
    end

    # /admin
    resource :admin do
      mount AdminMethods
    end
  end
end
