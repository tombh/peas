module Peas
  # Build an image for an app ready to be run in a pea
  class Builder
    def initialize(app, revision)
      @app = app
      @revision = revision
    end

    # Tar the repo to make moving it around more efficient
    def tar_repo
      @app.broadcast "#{@app.arrow}Tarring repo"
      unless File.directory? Peas::TMP_TARS
        FileUtils.mkdir_p Peas::TMP_TARS
        Peas.sh "chmod a+w #{Peas::TMP_TARS}" # Allow any user to write to the temp tars directory
      end
      @tmp_tar_path = "#{Peas::TMP_TARS}/#{@app.name}.tar"
      File.delete @tmp_tar_path if File.exist? @tmp_tar_path
      Peas.sh "cd #{@app.local_repo_path} && git archive #{@revision} > #{@tmp_tar_path}", user: Peas::GIT_USER
    end

    # Create a new Docker image based on progrium/buildstep with the repo placed at /app
    def create_build_container
      # There's an issue with Excon's buffer so we need to manually lower the size of the chunks to
      # get a more interactive-style attachment.
      # Follow the issue here: https://github.com/swipely/docker-api/issues/77
      conn_interactive = Docker::Connection.new(Peas::DOCKER_SOCKET, chunk_size: 1, read_timeout: 1_000_000)
      @container = Docker::Container.create(
        {
          'Image' => 'progrium/buildstep',
          'Env' => @app.config_for_docker,
          'OpenStdin' => true,
          'StdinOnce' => true,
          'Cmd' => [
            '/bin/bash',
            '-c',
            "mkdir -p /app && tar -xf - -C /app && /build/builder"
          ]
        },
        conn_interactive
      )
    end

    # Run the buildstep script and commit an image. Usually this will involve running Heroku buildpacks, etc
    def create_app_image
      # Stream the output of the the buildstep process
      build_error = false
      last_message = nil
      @container.tap(&:start).attach(stdin: File.open(@tmp_tar_path)) do |stream, chunk|
        # Save the error for later, because we still need to clean up the container
        build_error = chunk if stream == :stderr
        last_message = chunk # In case error isn't sent through :stderr
        @app.broadcast chunk.encode('utf-8', invalid: :replace, undef: :replace, replace: '')
      end
      # Commit the container with the newly built app as a new image named after the app
      if @container.wait['StatusCode'] == 0
        @container.commit 'repo' => @app.name
      else
        build_error = "Buildstep failed with non-zero exit status. " \
          "Error message was: '#{build_error}'. " \
          "Last message was: '#{last_message}'."
      end

      # Keep a copy of the build container's details
      builder_json = @container.json

      # Make sure to clean up after ourselves
      begin
        @container.kill
        @container.delete force: true
      rescue Docker::Error::NotFoundError, Errno::EPIPE, Excon::Errors::SocketError
      end

      raise Peas::PeasError, build_error.strip if build_error

      builder_json
    end
  end
end
