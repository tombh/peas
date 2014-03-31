module Peas
  class HeaderVersioning < Grape::API
    version 'v1', using: :header, vendor: 'Peas', format: :json, strict: true
    desc "Returns Peas."
    get do
      { header: "Peas" }
    end
  end
end
