module Peas
  class PathVersioning < Grape::API
    version 'vendor', using: :path, vendor: 'Peas', format: :json
    desc "Returns Peas."
    get do
      { path: "Peas" }
    end
  end
end
