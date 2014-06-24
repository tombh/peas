# Convenience functions to allow long-running tasks such as system calls to be run asynchronously
# with callbacks and for their statuses to be broadcast and bubbled up through nested worker
# processes. Only compatible with Mongoid model instances.
#
# By including this module the model can take on 2 extra properties;
#   1. It can pass off execution flow to another running version of this code, likely on an entirely
#      different machine.
#   2. It can accept jobs created by 1). Whereas as 1) is most likely to occur inside a web request or
#      console or rake task, 2) is triggered by a worker manager job queue.
module ModelWorker

  # A human-friendly string for prepending to log lines.
  # Gets set in WorkerRunner.
  attr_accessor :current_worker_call_sign

  # The parent job ID. Used when nested, jobs-within-jobs are a created. Child jobs can then
  # broadcast their status to the parent job and so any listeners to the parent job can hear the
  # progress of all decedent jobs.
  attr_accessor :job

  # This class serves no other purpose than the cosmetic convenience of being able to chain
  # a method-call onto `worker()` like so; `self.worker(:optimal_pod).scale(web: 1)`
  class ModelProxy
    def initialize pod_id, block_until_complete, instance
      @pod_id = pod_id
      @block_until_complete = block_until_complete
      @instance = instance
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
      current_job = SecureRandom.uuid
      # Only set the parent_job if this is the first job
      @instance.job = current_job if !@instance.job
      # Open up a pubsub publisher to add a job to the worker queue
      socket = Peas::Switchboard.connection
      socket.puts "publish.jobs_for.#{@pod_id}"
      # Package up the job
      job = {
        parent_job: @instance.job,
        current_job: current_job,
        model: @instance.class.name,
        id: @instance._id.to_s,
        method: method,
        args: args
      }.to_json
      # Place the job on the queue
      socket.puts job
      # Broadcast the fact that the job is now queued and waiting to be run
      @instance.broadcast({status: 'queued'})
      # Return the job for those interested in its progress
      current_job
    end

    # Manage the execution of worker code.
    #
    # `method`: the model method to call
    # `*args` list of arguments for the @method
    # `&block` callback on completion
    def worker_manager method, *args, &block
      current_job = create_job method, args
      # Wait for current_job to finish before running subsequent tasks
      if block_given? || @block_until_complete
        socket = Peas::Switchboard.connection
        socket.puts "subscribe.job_progress.#{current_job}"
        while response = socket.gets do
          puts "!!!!!!!!"
          puts response
          puts "!!!!!!!!"
          progress = JSON.parse response
          status = progress['status']
          break if status != 'working' && status != 'queued'
        end
        if status == 'failed'
          raise "Worker for #{@instance.class.name}.#{method} failed. Job aborted."
        elsif status == 'complete'
          yield if block_given?
        else
          raise "Unexpected status (#{status}) received from job_progress channel"
        end
      end
      current_job
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
  def worker pod_id = :controller, block_until_complete: false, parent_job: nil
    pod_id = Pod.optimal_pod if pod_id == :optimal_pod
    self.job = parent_job if parent_job
    # ModelProxy exposes a method_missing() method to catch the chained methods
    ModelProxy.new pod_id, block_until_complete, self
  end

  # Open a socket to the pubsub channel for this job, so that other processes can listen to progress
  def open_broadcaster
    @broadcaster = Peas::Switchboard.connection
    @broadcaster.puts "publish.job_progress.#{@job}"
  end

  # Convenience function for updating a job status and logging from within the models.
  def broadcast message
    raise 'broadcast() can only be used if method is part of a running job.' if !@job
    open_broadcaster if !@broadcaster
    message[:status] == 'working' if !message[:status]
    message = message.to_json.force_encoding("UTF-8")
    log message, @current_worker_call_sign if self.class.name == 'App' # Also log to the app's aggregated logs
    @broadcaster.puts message
  end

  # Stream shell output
  def stream_sh command, broadcastable = true
    accumulated = ''
    # Redirects STDOUT and STDERR to STDOUT
    IO.popen("#{command} 2>&1", chdir: Peas.root) do |data|
      while line = data.gets
        if line =~ /docker.sock: permission denied/
          broadcastable = true
          @custom_error = "The user running Peas does not have permission to use docker. You most" +
            "likely need to add your user to the docker group, eg: \`gpasswd -a <username> " +
            "docker\`. And remember to log in and out to enable the new group."
        end
        accumulated += line
        broadcast line if broadcastable
      end
      data.close
      if $?.to_i > 0
        if @custom_error
          raise @custom_error
        else
          broadcast accumulated
          raise "#{command} exited with non-zero status"
        end
      end
    end
    return accumulated.strip
  end

  # Same as stream_sh but doesn't broadcast the ouput to Sidekiq::Status
  def sh command
    stream_sh command, false
  end

end
