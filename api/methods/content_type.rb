module Peas
  class ContentType < Grape::API
    format :json
    content_type :txt, "text/plain"

    desc "Returns a plain text file."
    get "data" do
      content_type "text/plain"
      "A red brown fox jumped over the road."
    end
  end
end
