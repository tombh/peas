ENV['RACK_ENV'] ||= "test"

module Peas
  def self.root
    File.join(File.dirname(__FILE__), "../")
  end
  def self.environment
    ENV['RACK_ENV']
  end
  def self.domain
    setting = Setting.where(key: 'domain')
    if setting.count == 1
      setting.first.value
    else
      'vcap.me:4000'
    end
  end
end

$LOAD_PATH.unshift(Peas.root)

require 'config/boot'
