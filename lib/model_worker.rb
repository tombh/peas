# Convenience functions to allow long-running tasks such as system calls to be run asynchronously
# with callbacks and for their statuses to be broadcast and bubbled up through nested worker
# processes. Only compatible with Mongoid model instances.
#
# By including this module the model can take on 2 extra properties;
#   1. It can pass off execution flow to another running version of this code, likely on an entirely
#      different machine.
#   2. It can accept jobs created by 1). Whereas as 1) is most likely to occur inside a web request or
#      console or rake task, 2) is triggered by a worker manager job queue.
module Peas::ModelWorker
  # The parent job ID. Used when nested, jobs-within-jobs are a created. Child jobs can then
  # broadcast their progress to the parent job and so any listeners to the parent job can hear the
  # progress of all decedent jobs.
  attr_accessor :parent_job

  # The current job ID. If this is a nested job then this ID will be different from the parent job
  attr_accessor :current_job

  # The current state of the current job, either; 'queued', 'working', 'complete' or 'failed'
  attr_reader :worker_status

  # A human-friendly string for prepending to log lines.
  # Gets set in WorkerRunner.
  attr_accessor :worker_call_sign

  # This class serves no other purpose than the cosmetic convenience of being able to chain
  # a method-call onto `worker()` like so; `self.worker(:optimal_pod).scale(web: 1)`
  class ModelProxy
    def initialize pod_id, block_until_complete, instance
      @pod_id = pod_id
      @block_until_complete = block_until_complete
      @instance = instance
      self
    end

    def method_missing method, *args, &block
      # Careful of the gotcha here. You still need to be told when a valid NameError (undefined local variable or
      # method) is raised
      if @instance.respond_to? method
        worker_manager method, *args, &block
      else
        super method, *args, &block
      end
    end

    # Notify a pod (or the controller) that it has a new job to do
    def create_job method, args
      # UUID's are guaranteed to be practically unique, as in *extremely* unlikely to collide
      new_job_id = SecureRandom.uuid
      # @is_parent_caller differentiates the parent job as originally called (outside a worker process) and the parent
      # job as run by a worker process.
      @is_parent_caller = false
      if @instance.parent_job
        # We're in a child job created by a worker process.
        # Inherit the parent_job to send progress details back to parent job. No need to set
        # @instance.current_job as that is set by WorkerRunner
        @inheritable_parent_job = @instance.parent_job
      else
        # We're in a parent job, either being called here for the first time or starting the first child job
        if !@instance.current_job
          # This is just the first call to a parent job (though that doesn't imply children will be created)
          @is_parent_caller = true
        end
        @inheritable_parent_job = new_job_id
      end
      @instance.current_job = new_job_id
      # Open up a pubsub publisher to add a job to the worker queue
      socket = Peas::Switchboard.connection
      socket.puts "publish.jobs_for.#{@pod_id}"
      # Package up the job
      job = {
        parent_job: @inheritable_parent_job,
        current_job: new_job_id,
        model: @instance.class.name,
        id: @instance._id.to_s,
        method: method,
        args: args
      }.to_json
      # Place the job on the queue
      socket.puts job
      socket.close
      # Broadcast the fact that the job is now queued and waiting to be run
      @instance.worker_status = 'queued'
      # Return the job for those interested in its progress
      new_job_id
    end

    # Manage the execution of worker code.
    #
    # `method` the model method to call
    # `*args` list of arguments for the @method
    # `&block` callback on completion
    def worker_manager method, *args, &block
      new_job_id = create_job method, args
      # Wait for job to finish before running subsequent tasks
      if block_given? || @block_until_complete
        socket = Peas::Switchboard.connection
        socket.puts "subscribe.job_progress.#{new_job_id} history"
        # Execution will only proceed if the job is taken up by a worker process
        while response = socket.gets do
          progress = JSON.parse response
          status = progress['status']
          break if status == 'complete' || status == 'failed'
        end
        if status == 'failed'
          if @is_parent_caller
            # Only raise an error in the parent worker that started off the whole process
            error_message = "Worker for #{@instance.class.name}.#{method} failed. Job aborted. " + progress['body']
            raise Peas::ModelWorkerError, error_message
          else
            @instance.broadcast({status: 'failed', body: 'Child worker failed, so aborting parent worker.'})
          end
        elsif status == 'complete'
          # Note that the `status` we're checking here was set by a worker process, so it's not within the same scope
          # (or even the same machine!), so we need to set the status here for any broadcasts that occur in the `yield`
          @instance.worker_status = 'callback'
          yield if block_given?
        else
          raise Peas::ModelWorkerError, "Unexpected status (#{status}) received from job_progress channel"
        end
      end
      new_job_id
    end

  end

  # Any existing model method that is chained with worker() is run as a worker process.
  #
  # = Usage
  #   Without a block (`worker(:optimal_pod).create!(key: value)`) returns instantly with a job ID.
  #   With a block (`worker.create!(key: value){ callback() }`) execution flow is blocked until the
  #   callback completes.
  #
  #   Note that only hashes, lists and primitives (ie. JSON-serialisable) can be passed as arguments
  #   in the chained method.
  #
  # * `pod_id` Pod that will run the job. Either the controller or a distributed pod.
  #   `pod_id` also accepts two special values, `:controller` and `:optimal_pod`.
  #   `:controller` runs the job on the Controller (where the API, etc lives).
  #   `:optimal_pod` finds the pod with the most amount of free resources.
  #
  # * `block_until_complete` Flag to block execution flow until the worker process is complete. It's
  #   the same as doing something like `worker.build{}` (note the empty block braces). A friendly
  #   programmer will instead use the more verbose `worker(pod_id, block_until_complete: true) to clearly
  #   convey intent.
  #
  # * `parent_job` For when you need to manually specify the parent job. Eg; when a job has already
  #   been created in another model.
  #
  # Returns a job ID
  def worker pod_id = :controller, block_until_complete: false, parent_job_id: nil
    pod_id = Pod.optimal_pod if pod_id == :optimal_pod
    @parent_job = parent_job_id if parent_job_id
    # ModelProxy exposes a method_missing() method to catch the chained methods
    ModelProxy.new pod_id, block_until_complete, self
  end

  # Send status updates for the current and pareant jobs, so that other processes can listen to progress
  def broadcasters message
    # Broadcast to current and parent. But only both if they're actually different jobs
    [@current_job, @parent_job].uniq.each do |job|
      next if !job
      socket = Peas::Switchboard.connection
      socket.puts "publish.job_progress.#{job} history"
      # Don't update the parent job's status with the current job's status, unless it's to notify of failure.
      # All we want to do is make sure that parent job gets human-readable progress details from child jobs.
      if (job == @parent_job) && (@current_job != @parent_job)
        message.delete :status if message[:status] != 'failed'
      end
      socket.puts message.to_json if message != {}
      socket.close
    end
  end

  # Convenience function for updating a job status and logging from within the models.
  def broadcast message = {}
    raise 'broadcast() can only be used if method is part of a running job.' if !@current_job
    message = message.to_s if !message.is_a?(Hash)
    if message.is_a? String
      tmp_msg = message
      message = {}
      message[:body] = tmp_msg
    end
    if message[:status]
      @worker_status = message[:status]
    else
      message[:status] = @worker_status
    end
    log message[:body], @worker_call_sign if self.class.name == 'App' # Also log to the app's aggregated logss
    broadcasters message
  end

  # Broadcast the status every time it is set
  def worker_status= status
    @worker_status = status
    broadcast({status: status})
  end

  # Stream shell output
  def stream_sh command, broadcastable = true
    accumulated = ''
    # Redirects STDOUT and STDERR to STDOUT
    IO.popen("#{command} 2>&1", chdir: Peas.root) do |data|
      while line = data.gets
        broadcast line if broadcastable
      end
      data.close
      if $?.to_i > 0
        broadcast accumulated
        raise Peas::ShellError, "#{command} exited with non-zero status"
      end
    end
    return accumulated.strip
  end

  # Same as stream_sh but doesn't broadcast the ouput
  def sh command
    stream_sh command, false
  end

end
