module Peas
  class AdminMethods < Grape::API
    desc "Show all the available settings"
    get :settings do
      settings = {
        defaults: Setting.all,
        services: Peas.available_services
      }
      respond settings
    end

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
      respond nil
    end
  end
end
