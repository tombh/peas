# Worker for all long-running API tasks to inherit from
class ModelWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  # Wrap perform() so that we can rescue errors and publish them to Sidekiq's
  # status and ultimately transmit all output back to the calling user interface, most likely
  # the Peas CLI client.
  def perform(model, id, method, *args)
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
      # A human-friendly string for the prepending to log lines
      instance.current_worker_call_sign = "#{model}.#{method}.worker"
      # The actual work to do
      instance.send(method, *args)
    rescue => e
      if Peas.environment == 'development'
        logger.error e.message
        logger.debug e.backtrace.join("\n")
        # Pass the error back to the command line
        Sidekiq::Status.broadcast @job, {error: "#{e.message} @ #{e.backtrace[0]}"}
      else
        raise e
      end
    end
  end

end