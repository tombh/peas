# This class serves allows for the cosmetic convenience of being able to chain
# a method-call onto `worker()` like so; `self.worker(:optimal_pod).scale(web: 1)`
module Peas
  module ModelWorker
    class ModelProxy
      def initialize(pod, block_until_complete, instance)
        raise PeasError, "Trying to create a worker job without specifying a pod to run it on." if !pod
        @pod = pod
        @block_until_complete = block_until_complete
        @instance = instance
        self
      end

      def method_missing(method, *args, &block)
        # Careful of the gotcha here. You still need to be told when a valid NameError (undefined local variable or
        # method) is raised
        if @instance.respond_to? method
          worker_manager method, *args, &block
        else
          super method, *args, &block
        end
      end

      # Notify a pod (or the controller) that it has a new job to do
      def create_job(method, args)
        # UUID's are guaranteed to be practically unique, as in *extremely* unlikely to collide
        new_job_id = SecureRandom.uuid
        # @is_parent_caller differentiates the parent job as originally called (outside a worker process) and the parent
        # job as run by a worker process.
        @is_parent_caller = false
        # The parent_job is the very first job that can trigger any number of child jobs. It provides an access point
        # for listeners to keep track of all subsequent child jobs.
        unless @instance.parent_job
          @instance.parent_job = new_job_id
          # We know this is the parent caller process because @instance.current_job is only set below and by WorkerRunner
          @is_parent_caller = true unless @instance.current_job
        end
        # Need to be very careful about setting the current_job. Mainly you need to remember that a job begins in one
        # place (ie the caller process), but is run in another (ie the worker process), but the code is the same :/
        # And to add to that confusion a worker process can *also* be a caller to create a new child job! So current_job
        # needs to be strictly maintained. A worker process should never start life with one job ID and then change job ID
        # just because it's created a child job.
        @instance.current_job = new_job_id unless @instance.current_job
        # Open up a pubsub publisher to add a job to the worker queue
        socket = Peas::Switchboard.connection
        socket.puts "publish.jobs_for.#{@pod}"
        # Package up the job
        job = {
          parent_job: @instance.parent_job,
          current_job: new_job_id,
          model: @instance.class.name,
          id: @instance._id.to_s,
          method: method,
          args: args
        }.to_json
        # Place the job on the queue
        socket.puts job
        socket.close
        # Broadcast the fact that the job is now queued and waiting to be run. Not that we can't use
        # @instance.worker_status because this status refers to a new job.
        socket = Peas::Switchboard.connection
        socket.puts "publish.job_progress.#{new_job_id} history"
        socket.puts({
          status: 'queued',
          job_id: new_job_id
        }.to_json)
        # Return the job for those interested in its progress
        new_job_id
      end

      # Manage the execution of worker code.
      #
      # `method` the model method to call
      # `*args` list of arguments for the @method
      # `&block` callback on completion
      def worker_manager(method, *args, &_block)
        new_job_id = create_job method, args
        # Wait for job to finish before running subsequent tasks
        if block_given? || @block_until_complete
          socket = Peas::Switchboard.connection
          socket.puts "subscribe.job_progress.#{new_job_id} history"
          # Execution will only proceed if the job is taken up by a worker process
          while response = socket.gets
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
              @instance.broadcast(status: 'failed', body: 'Child worker failed, so aborting parent worker.')
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
  end
end
