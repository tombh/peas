require 'spec_helper'

describe WorkerHelper do
  let(:app) { Fabricate :app }

  it 'should get and set the @job instance variable' do
    app.job = '123'
    expect(app.job).to eq '123'
  end

  it 'should trigger a Sidekiq job with the correct arguments and return the job id' do
    job = app.worker :deploy
    expect(ModelWorker.jobs.size).to eq 1
    expect(ModelWorker).to have_enqueued_job('App', app._id.to_s, 'deploy')
    expect(job).to eq ModelWorker.jobs.first['jid']
  end

  it 'should wait for a worker to finish and then execute a given callback' do
    expect(ModelWorker).to receive(:perform_async) { '123' }
    # Weird stuff happened when I put exactly() on the Sidekiq::Status stub :| So it's on sleep
    # instead.
    expect(app).to receive(:sleep).exactly(3).times
    expect(Sidekiq::Status).to receive(:status).with('123').and_return(:queued, :working, :complete)
    job = app.worker :deploy do
      @callback_fired = true
    end
    expect(job).to eq '123'
    expect(@callback_fired).to eq true
  end

  describe 'Broadcasting messages' do
    it 'should format messages by typecasting to String and adding newlines' do
      app.job = '123'
      message = {'key' => "status\n"}
      expect(Sidekiq::Status).to receive(:broadcast).with('123', message)
      allow(Sidekiq::Status).to receive(:get_all) { {} }
      app.broadcast :status, :key
    end

    it 'should append to the existing log for a job' do
      app.job = '123'
      allow(Sidekiq::Status).to receive(:get_all) { {'key' => "status was 'ere\n" } }
      message = {'key' => "status was 'ere\nstatus\n"}
      expect(Sidekiq::Status).to receive(:broadcast).with('123', message)
      app.broadcast :status, :key
    end

    it 'should broadcast to the originating parent job in nested workers' do
      class App
        def parent_job
          worker :child_job
        end
        def child_job
          broadcast "it's a long way down"
        end
      end
      parent_jid = app.worker :parent_job
      expect(Sidekiq::Status).to receive(:broadcast).with(
        parent_jid,
        {"output"=>"it's a long way down\n"}
      )
      ModelWorker.drain
    end
  end

  describe 'Streaming shell commands' do
    it 'should run a shell command and broadcast its output' do
      expect(app).to receive(:broadcast).with('hi')
      app.stream_sh 'echo -n "hi"'
    end

    it 'should stream commands by broadcasting every new line' do
      expect(app).to receive(:broadcast).exactly(2).times
      app.stream_sh 'echo "hi" && echo "hi"'
    end

    it 'should propagate errors' do
      expect { app.stream_sh 'exit 1' }.to raise_error
    end

    it 'should raise a custom error message' do
      expect(app).to receive(:raise).with(/Peas does not have permission to use docker/)
      app.stream_sh 'echo "docker.sock: permission denied" && exit 1'
    end
  end

end
