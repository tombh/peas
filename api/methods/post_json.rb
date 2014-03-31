module Peas
  class PostJson < Grape::API
    format :json
    desc "Creates a spline that can be reticulated."
    resource :spline do
      post do
        { reticulated: params[:reticulated] }
      end
    end
  end
end
