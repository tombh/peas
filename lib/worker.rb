# Convenience functions to allow long-running tasks such as system calls to be run asynchronously
# with callbacks and for their statuses to be broadcast and bubbled up through nested worker
# processes
module Worker

  # A human-friendly string for prepending to log lines
  # Gets set in WorkerRunner
  attr_accessor :current_worker_call_sign

  # The current job ID
  attr_accessor :job

  # Wrapper function for triggering a worker, accepts a callback block.
  # Usage: `worker(:deploy, first_sha)`
  # or: `worker(:deploy, first_sha){ task_to_be_done_on_completion() }`
  # Is equivalent to: `ModelWorker(App, _id, :deploy, first_sha, {job: @job}).perform_async()`
  def worker *args, &block
    args.append({job: @job}) if @job
    method = args.shift
    @current_job = create_job(self.class.name, _id.to_s, method, *args)
    # Wait for @current_job to finish before running subsequent tasks
    if block_given?
      begin
        sleep 0.1
        status = Sidekiq::Status.status @current_job
      end while status == :queued || status == :working
      if status == :complete
        if status == :failed
          raise "Worker for #{self.class.name}.#{method} failed. ABORTING."
        else
          yield
        end
      end
    end
    @current_job
  end

  def create_job
  end

  # Convenience function for updating a job status and logging from within the models
  def broadcast status = nil, key = :output
    status = status.to_s
    key = key.to_s
    status = "#{status}\n" if !status.end_with? "\n" # Make sure everything is a line
    # Also log to the app's aggregated logs
    self.log status, @current_worker_call_sign
    # Append to the current status, so no statuses are ever lost
    current = Sidekiq::Status.get_all @job
    status = current[key] + status.force_encoding("UTF-8") if current[key]
    Sidekiq::Status.broadcast @job, {key => status}
  end

  # Stream shell output to Sidekiq job status
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
