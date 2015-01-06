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
      before do
        authenticate!
      end

      # GET /admin/settings
      desc "Show all the available settings"
      get :settings do
        respond current_settings
      end

      # PUT /admin/settings
      desc "Update Peas' settings"
      put :settings do
        params.each do |key, value|
          next if key == 'route_info'
          setting = Setting.where(key: key)
          if setting.count == 1
            setting.first.update_attributes(value: value)
          else
            Setting.create(key: key, value: value)
          end
        end
        respond current_settings
      end
    end
  end
end
