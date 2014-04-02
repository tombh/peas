require 'httparty'

class API
  include HTTParty
  base_uri 'localhost:3004'

  def request verb, method, params
    response = self.class.send(verb, "/#{method}", {query: params}).body
    json = JSON.parse(response)

    # Check to see if this is a long-running job
    if json.has_key? 'job'
      # Rudimentary long-polling to stream the status of a job
      begin
        sleep 0.5
        # API request to the /status method
        status = JSON.parse self.class.send(:get, '/status', {query: {job: json['job']}}).body
        puts status['output'].strip
        # The :status key is usually 'working' or 'complete'
        complete = status['status'] == 'complete'
      end while !complete
    else
      puts response
    end
  end
end