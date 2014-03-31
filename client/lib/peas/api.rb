require 'httparty'

class API
  include HTTParty
  base_uri 'localhost:9292'

  def request verb, method, params
    puts self.class.send(verb, "/#{method}", {query: params}).body
  end
end