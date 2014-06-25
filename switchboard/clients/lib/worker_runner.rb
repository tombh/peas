class WorkerRunner
  def initialize job
    perform JSON.parse(job)
  end

  def perform job
    model = job['model'] # eg; App
    id = job['id'] # eg; App._id
    method = job['method'] # eg; App.scale
    args = job['args'] # eg; { web: 1, workers: 2}
    # Instantiate the model instance
    instance = model.constantize.find_by(_id: id)
    # Set the parent job id so any sub worker processes can inherit and broadcast to it
    instance.parent_job = job['parent_job']
    # The current job needs to broadcast its status so any code waiting on its completion knows when to run
    instance.current_job = job['current_job']
    # A human-friendly string for prepending to log lines
    instance.worker_call_sign = "#{model}.#{method}.worker"
    # The actual work to do
    instance.worker_status = 'working'
    begin
      instance.send(method, *args)
    rescue => e
      instance.broadcast({
        status: 'failed',
        body: "#{e.message} @ #{e.backtrace[0]}"
      })
      raise e
    end
    instance.worker_status = 'complete'
  end
end