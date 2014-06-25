require 'spec_helper'

describe ModelWorker do
  let(:app) { Fabricate :app }

  before :each do
    allow_any_instance_of(App).to receive(:deploy).and_return(:success)
  end

  it 'should get and set the @job instance variable' do
    app.job = '123'
    expect(app.job).to eq '123'
  end

  it 'should trigger a Sidekiq job with the correct arguments and return the job id' do
    job_id = app.worker.deploy
    job = {
      parent_job: uuid,
      current_job: uuid,
      model: 'App',
      id: peas_app._id.to_s,
      method: 'deploy',
      args: []
    }
    expect(@socket).to receive(:puts).with(job.to_json)
    expect(@socket).to receive(:puts).with("publish.job_progress.#{uuid}")
    expect(@socket).to receive(:puts).with('{"status":"queued"}')
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

    it 'should log build activity to app logs' do
      expect(ModelWorker).to receive(:perform_async) { '123' }
      allow(Sidekiq::Status).to receive(:broadcast)
      allow(Sidekiq::Status).to receive(:get_all) { {} }
      allow(Sidekiq::Status).to receive(:status).with('123').and_return(:queued, :working, :complete)
      app.worker :build do
        app.worker_call_sign = 'builder'
        app.broadcast 'Build activity'
      end
      expect(app.logs_collection.find.first['line']).to include 'app[builder]: Build activity'
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

  describe 'Shell commands' do
    it 'should run a shell command and broadcast its output' do
      expect(app).to receive(:broadcast).with('hi')
      app.stream_sh 'echo -n "hi"'
    end

    it 'should return the total accumulated output stipped()' do
      output = app.stream_sh 'echo "line1\nline2"'
      expect(output).to eq("line1\nline2")
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

    it 'should not broadcast ouput when sh() is used' do
      expect(app).to_not receive(:broadcast)
      app.sh 'echo -n "hi"'
    end
  end

  describe "Calling the model's method" do
    it 'should instantiate the correct model object' do
      expect(App).to receive(:where).with({_id: app.id.to_s}).and_return([app])
      ModelWorker.new.perform 'App', app.id.to_s, :deploy
    end

    it 'should call the correct method with the given arguments on the passed model' do
      expect_any_instance_of(App).to receive(:deploy).with('argument', :more)
      ModelWorker.new.perform 'App', app.id.to_s, :deploy, 'argument', :more
    end
  end

  describe 'Setting the job id' do
    it 'should not propogate the job id as an arg to the called worker method' do
      expect_any_instance_of(App).to receive(:deploy).with(:arg)
      ModelWorker.new.perform 'App', app.id.to_s, :deploy, :arg, {'job' => '123'}
    end

    it 'should set the job id against the model instance if passed as an argument' do
      expect_any_instance_of(App).to receive(:job=).with('123')
      ModelWorker.new.perform 'App', app.id.to_s, :deploy, :arg, {'job' => '123'}
    end

    it 'should set the Sidekiq job id and propagate it if no job id passed as an argument' do
      worker = ModelWorker.new
      expect_any_instance_of(App).to receive(:job=).with(worker.jid)
      ModelWorker.new.perform 'App', app.id.to_s, :deploy
    end
  end

  describe "Catching exceptions" do
    it 'should catch exceptions in development and log and broadcast them' do
      allow(Peas).to receive(:environment).and_return('development')
      expect_any_instance_of(Logger).to receive(:error)
      expect_any_instance_of(Logger).to receive(:debug)
      expect_any_instance_of(App).to receive(:broadcast).with(
        /ERROR: undefined method `non_existent_method'/
      )
      expect(Sidekiq::Status).to receive(:broadcast).with(
        nil,
        error: /undefined method `non_existent_method'/
      )
      expect {
        ModelWorker.new.perform 'App', app.id.to_s, :non_existent_method
      }.to raise_error NoMethodError
    end

    it 'should propagate exceptions in non development environments' do
      expect_any_instance_of(App).to receive(:broadcast).with(
        /ERROR: undefined method `non_existent_method'/
      )
      expect {
        ModelWorker.new.perform 'App', app.id.to_s, :non_existent_method
      }.to raise_error NoMethodError
    end
  end
end
