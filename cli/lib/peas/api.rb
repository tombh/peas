require 'httparty'

class API
  include HTTParty

  LONG_POLL_TIMEOUT = 10 * 60
  LONG_POLL_INTERVAL = 0.5

  # This allows base_uri to be dynamically set. Useful for testing
  def initialize
    self.class.base_uri Peas.config['domain'] || 'localhost:4000'
  end

  # Generic wrapper to the Peas API
  def request verb, method, params
    response = self.class.send(verb, "/#{method}", {query: params}).body
    if response
      json = JSON.parse(response)
    else
      json = {}
    end
    # If there was an HTTP-level error
    raise json['error'].color(:red) if json.has_key? 'error'
    # Successful responses
    if json.has_key? 'job'
      # Long-running jobs need to poll a job status endpoint
      long_running_output json['job']
    else
      # Normal API repsonse
      puts json['message']
    end
  end

  # Rudimentary long-polling to stream the status of a job.
  def long_running_output job
    count = 0
    begin
      sleep LONG_POLL_INTERVAL
      # API request to the /status endpoint
      status = JSON.parse self.class.send(:get, '/status', {query: {job: job}}).body
      if status['status'] != 'failed'
        if status['output']
          # Don't output the accumulated progress log every time. Just output the difference
          output_diff status['output']
        end
        # Theoretically all worker errors should be caught and handled gracefully
        if status['error']
          puts
          raise status['error'].color(:red)
        end
      else
        # Uncaught error or production environment error
        raise "Long-running job failed. See worker logs for details.".color(:red)
      end
      count += 1
    end while status['status'] == 'working' && (count * LONG_POLL_INTERVAL) < LONG_POLL_TIMEOUT
  end

  # The Sidekiq status gem allows you to set custom variables associated with a job. So the worker
  # appends to an 'output' variable that accumulates the total log data. So we don't want to output
  # the 'total' output on every long-polled request. We just want to output any *new* log lines.
  def output_diff log_so_far
    @accumulated_output ||= ''
    old_count = @accumulated_output.lines.count
    new_count = log_so_far.lines.length
    diff = log_so_far.lines[old_count..new_count]
    @accumulated_output = log_so_far
    puts diff.join if diff.length > 0
  end

end