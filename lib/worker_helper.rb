# Convenience functions to allow long-running tasks such as system calls to be run asynchronously
# with callbacks and for their status to broadcast and bubbled up through nested worker processes
module WorkerHelper

  def job= jid
    @job = jid
  end

  def job
    @job
  end

  # Wrapper function for triggering a worker, accepts callback block.
  # Usage: `worker(:deploy, first_sha)`
  # or: `worker(:deploy, first_sha){ task_to_be_done_on_completion() }`
  # Is equivalent to: `ModelWorker(App, _id, :deploy, first_sha, {job: @job}).perform_async()`
  def worker *args
    args.append({job: @job}) if @job
    @current_job = ModelWorker.perform_async(self.class.name, _id.to_s, args.shift, *args)
    # Wait for @current_job to finish before running subsequent tasks
    if block_given?
      begin
        sleep 0.1
        status = Sidekiq::Status.status @current_job
      end while status == :queued || status == :working
      if status == :complete
        yield
      end
    end
    @current_job
  end

  # Convenience function for updating a job status from within the models
  def broadcast status = nil, key = :output
    status = status.to_s
    key = key.to_s
    status = "#{status}\n" if !status.end_with? "\n" # Make sure everything is a line
    # Append to the current status, so no statuses are ever lost
    current = Sidekiq::Status.get_all @job
    status = current[key] + status if current[key]
    Sidekiq::Status.broadcast @job, {key => status}
  end

  # Stream output to Sidekiq job status
  def stream_sh command, broadcastable = true
    accumulated = ''
    # Redirects STDOUT and STDERR to STDOUT
    IO.popen("#{command} 2>&1", chdir: Peas.root) do |data|
      while line = data.gets
        if line =~ /docker.sock: permission denied/
          broadcastable = true
          @custom_error = """The user running Peas does not have permission to use docker. You most likely need to add \
your user to the docker group, eg: \`gpasswd -a <username> docker\`. And remember to log in and out to enable the \
new group."""
        end
        accumulated += line
        broadcast line if broadcastable
      end
      data.close
      if $?.to_i > 0
        if @custom_error
          raise @custom_error
        else
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
