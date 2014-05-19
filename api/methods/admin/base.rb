module Peas
  class AdminMethods < Grape::API; end
  class API < Grape::API
    # /admin
    resource :admin do
      mount AdminMethods
    end
  end
end