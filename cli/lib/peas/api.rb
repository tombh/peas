require 'httparty'

class API
  include HTTParty
  base_uri 'localhost:3004'

  def request verb, method, params
    response = self.class.send(verb, "/#{method}", {query: params}).body
    json = JSON.parse(response)
    raise json['error'].color(:red) if json.has_key? 'error'

    # Check to see if this is a long-running job
    if json.has_key? 'job'
      # Rudimentary long-polling to stream the status of a job
      begin
        sleep 0.5
        # API request to the /status method
        status = JSON.parse self.class.send(:get, '/status', {query: {job: json['job']}}).body
        if status['status'] != 'failed'
          puts status['output'].strip
        else
          raise "Long-running job failed. See worker logs for details.".color(:red)
        end
      end while status['status'] == 'working' # The :status key is usually 'working', 'complete' or 'failed'
    else
      puts json['message']
    end
  end
end