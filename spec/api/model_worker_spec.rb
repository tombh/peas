require 'spec_helper'

describe ModelWorker, :with_worker do
  let(:app) { Fabricate :app }
  let(:uuid) {'b962c3db-9170-4962-9a7b-91db1a809c91'}
  let(:uuid2) {'b8d2cdbd6-d3d4-4d2f-8f48-96325a4f2cd6'}

  before :each do
    class App; def fake; broadcast 'carpe'; broadcast 'diem'; end end
    allow(SecureRandom).to receive(:uuid).and_return(uuid, uuid2)
  end


  it 'should enqueue a job with the correct arguments and return the job id' do
    job = {
      parent_job: uuid,
      current_job: uuid,
      model: 'App',
      id: app._id.to_s,
      method: 'deploy',
      args: []
    }
    expect(WorkerRunner).to receive(:new).with("#{job.to_json}\n")
    job_id = app.worker.deploy
    expect(job_id).to eq uuid
  end

  it 'should call the correct method with the given arguments on the passed model' do
    allow(app).to receive(:broadcast)
    expect(App).to receive(:find_by).with({_id: app.id.to_s}).and_return(app)
    expect(app).to receive(:fake).with('argument', 'more')
    WorkerRunner.new({
      model: 'App',
      method: 'fake',
      id: app._id.to_s,
      args: ['argument', :more]
    }.to_json)
  end

  it 'should wait for a worker to finish and then execute a given callback' do
    app.worker.fake do
      @callback_fired = true
    end
    expect(@callback_fired).to eq true
  end

  it 'should be able to send and run jobs to particular workers'

  it 'using :optimal_pod should find the least burdened pod and send a job to it'

  describe 'Broadcasting messages' do
    it 'should broadcast messages and preserve history' do
      job_listener = client_connection
      job_listener.puts "subscribe.job_progress.#{uuid} history"
      app.worker.fake
      progress = []
      while line = JSON.parse(job_listener.gets) do
        progress << line
        break if line['status'] == 'complete'
      end
      expect(progress).to eq [
        {"status"=>"queued"},
        {"status"=>"working"},
        {"body"=>"carpe", "status"=>"working"},
        {"body"=>"diem", "status"=>"working"},
        {"status"=>"complete"}
      ]
    end

    it 'should log activity to app logs if the job is on an App model' do
      app.current_job = uuid
      app.worker_call_sign = 'testing'
      app.broadcast :test
      expect(app.logs_collection.find.first['line']).to include 'app[testing]: test'
    end

    it 'should broadcast to the originating parent job in nested workers' do
      class App
        def parent_worker
          worker(block_until_complete: true).child_worker
        end
        def child_worker
          broadcast "it's a long way down"
        end
      end
      parent_job = app.worker(block_until_complete: true).parent_worker
      job_listener = client_connection
      job_listener.puts "subscribe.job_progress.#{parent_job} history"
      progress = []
      while line = JSON.parse(job_listener.gets) do
        progress << line
        break if line['status'] == 'complete'
      end
      expect(progress).to include({"body"=>"it's a long way down"})
    end
  end

  describe 'Setting the job id' do
    it 'should set parent and current IDs to be the same for first jobs' do
      job_id = app.worker(block_until_complete:true).fake
      expect(app.parent_job).to eq nil
      expect(app.current_job).to eq uuid
      expect(job_id).to eq uuid
    end

    it 'should set the parent job id against the model instance if passed as an argument' do
      app.current_job = uuid
      app.worker(parent_job_id: 'manualID').fake
      expect(app.parent_job).to eq 'manualID'
    end

    it "should set a child job's ID with the parent ID and a new job ID" do
      app.current_job = 'currentID'
      app.parent_job = 'parentID'
      allow(App).to receive(:find_by).with({_id: app.id.to_s}).and_return(app)
      app.worker(block_until_complete:true).fake
      expect(app.parent_job).to eq 'parentID'
      expect(app.current_job).to eq uuid
    end
  end

  describe "Catching exceptions" do
    it 'should catch exceptions and broadcast them' do
      allow(app).to receive(:broadcast)
      allow(App).to receive(:find_by).with({_id: app.id.to_s}).and_return(app)
      # expect(app).to receive(:broadcast).with(
      #   /ERROR: undefined method `non_existent_method'/
      # )
      job = {
        current_job: uuid,
        model: 'App',
        id: app.id.to_s,
        method: :non_existent_method
      }.to_json
      expect {
        WorkerRunner.new(job)
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

  describe 'Shell commands' do
    it 'should run a shell command and broadcast its output' do
      expect(app).to receive(:broadcast).with('hi')
      app.stream_sh 'echo -n "hi"'
    end

    it 'should return the total accumulated output stipped()' do
      app.current_job = uuid
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
      app.current_job = uuid
      expect(app).to receive(:raise).with(/Peas does not have permission to use docker/)
      app.stream_sh 'echo "docker.sock: permission denied" && exit 1'
    end

    it 'should not broadcast ouput when sh() is used' do
      expect(app).to_not receive(:broadcast)
      app.sh 'echo -n "hi"'
    end
  end
end
