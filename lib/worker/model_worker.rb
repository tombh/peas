# Convenience functions to allow long-running tasks such as system calls to be run asynchronously
# with callbacks and for their statuses to be broadcast and bubbled up through nested worker
# processes. Only compatible with Mongoid model instances.
#
# By including this module the model can take on 2 extra properties;
#   1. It can pass off execution flow to another running version of this code, likely on an entirely
#      different machine.
#   2. It can accept jobs created by 1). Whereas as 1) is most likely to occur inside a web request or
#      console or rake task, 2) is triggered by a worker manager job queue.
module Peas
  module ModelWorker
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
    def worker(pod_id = :controller, block_until_complete: false, parent_job_id: nil)
      pod_id = Pod.optimal_pod if pod_id == :optimal_pod
      @parent_job = parent_job_id if parent_job_id
      # ModelProxy exposes a method_missing() method to catch the chained methods
      ModelProxy.new pod_id, block_until_complete, self
    end

    # Send status updates for the current and pareant jobs, so that other processes can listen to progress
    def broadcasters(message)
      # Broadcast to current and parent. But only both if they're actually different jobs
      [@current_job, @parent_job].uniq.each do |job|
        socket = Peas::Switchboard.connection
        socket.puts "publish.job_progress.#{job} history"
        # Don't update the parent job's status with the current job's status, unless it's to notify of failure.
        # All we want to do is make sure that parent job gets human-readable progress details from child jobs.
        if (job == @parent_job) && (@current_job != @parent_job)
          message.delete :status if message[:status] != 'failed'
        end
        socket.puts message.to_json if message[:status] || message[:body]
        socket.close
      end
    end

    # Convenience function for updating a job status and logging from within the models.
    def broadcast(message = {})
      raise 'broadcast() can only be used if method is part of a running job.' unless @current_job
      message = message.to_s unless message.is_a?(Hash)
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
      message[:job_id] = @current_job
      log message[:body], @worker_call_sign if self.class.name == 'App' # Also log to the app's aggregated logss
      broadcasters message
    end

    # Broadcast the status every time it is set
    def worker_status=(status)
      @worker_status = status
      broadcast(status: status)
    end

    # Stream shell output
    def stream_sh(command, broadcastable = true)
      accumulated = ''
      # Redirects STDOUT and STDERR to STDOUT
      IO.popen("#{command} 2>&1", chdir: Peas.root) do |data|
        while line = data.gets
          accumulated += line
          broadcast line if broadcastable
        end
        data.close
        if $CHILD_STATUS.to_i > 0
          broadcast accumulated
          raise Peas::ShellError, "#{command} exited with non-zero status"
        end
      end
      accumulated.strip
    end

    # Same as stream_sh but doesn't broadcast the ouput
    def sh(command)
      stream_sh command, false
    end
  end
end
