module Peas
  class AdminMethods < Grape::API
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
    end
  end
end
