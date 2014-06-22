class WorkerRunner
  def initialize job, socket
    @socket = socket
    perform JSON.parse(job)
  end

  def perform job
    begin
      model = job[:model] # eg; App
      id = job[:id] # eg; App._id
      method = job[:method] # eg; App.scale
      args = job[:args] # eg; { web: 1, workers: 2}
      # Instantiate the model instance
      instance = model.constantize.find_by(_id: id)
      # Set the parent job id so any sub worker processes can inherit and broadcast to it
      instance.job = job[:parent_job]
      # A human-friendly string for prepending to log lines
      instance.current_worker_call_sign = "#{model}.#{method}.worker"
      # Open a ubsub channel to update lsiteners with the progress of this job
      instance.open_broadcaster
      # The actual work to do
      instance.broadcast({status: 'working'})
      instance.send(method, *args)
      instance.broadcast({status: 'complete'})
    rescue => e
      error = "#{e.message} @ #{e.backtrace[0]}"
      instance.broadcast({
        status: 'failed',
        error: error
      })
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