class WorkerRunner
  def initialize job, scoket
    @socket = socket
    model, id, method, *args = job
  end

  def perform job
    begin
      # Instantiate the model instance
      instance = model.constantize.find_by(_id: id)
      # Look for a job id in the arguments
      args.select{|arg| arg.is_a? Hash}.each do |hash|
        if hash.keys.length == 1 && hash.has_key?('job')
          @job = hash['job'] if hash['job'] != :none
        end
      end
      args.reject!{|arg| arg == {'job' => @job}}
      @job ||= jid # `jid` is provided by the Sidekiq module
      # Set the parent job id so any sub worker processes can inherit and broadcast to it
      instance.job = @job
      # A human-friendly string for prepending to log lines
      instance.current_worker_call_sign = "#{model}.#{method}.worker"
      # The actual work to do
      instance.send(method, *args)
    rescue => e
      error = "#{e.message} @ #{e.backtrace[0]}"
      instance.broadcast "ERROR: #{error}"
      if Peas.environment == 'development'
        logger.error e.message
        logger.debug e.backtrace.join("\n")
        # Pass the error back to the command line
        @socket.puts @job, {error: error}
      end
      raise e
    end
  end
end