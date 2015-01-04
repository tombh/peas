require 'spec_helper'

describe Peas::ModelWorker, :with_worker do
  let(:app) { Fabricate :app }
  let(:uuid) { 'b962c3db-9170-4962-9a7b-91db1a809c91' }
  let(:uuid2) { 'b8d2cdbd6-d3d4-4d2f-8f48-96325a4f2cd6' }

  before :each do
    class App; def fake; broadcast 'fake' end end # rubocop:disable Style/SingleLineMethods
    allow(SecureRandom).to receive(:uuid).and_return(uuid, uuid2)
  end

  it 'should enqueue a job with the correct arguments and return the job id' do
    job = {
      parent_job: uuid,
      current_job: uuid,
      model: 'App',
      id: app._id.to_s,
      method: 'fake',
      args: []
    }
    expect(WorkerRunner).to receive(:new).with("#{job.to_json}\n", 'controller').and_call_original
    job_id = app.worker(block_until_complete: true).fake
    expect(job_id).to eq uuid
  end

  it 'should call the correct method with the given arguments on the passed model' do
    allow(app).to receive(:broadcast)
    expect(App).to receive(:find_by).with(_id: app.id.to_s).and_return(app)
    expect(app).to receive(:fake).with('argument', 'more')
    WorkerRunner.new({
      model: 'App',
      method: 'fake',
      id: app._id.to_s,
      args: ['argument', :more]
    }.to_json, 'controller')
  end

  it 'should wait for a worker to finish and then execute a given callback' do
    app.worker.fake do
      @callback_fired = true
    end
    expect(@callback_fired).to eq true
  end

  describe 'Sending jobs to particular workers' do
    before :each do
      expect(App).to receive(:find_by).with(_id: app.id.to_s).and_return(app)
      allow(app).to receive(:broadcast).and_call_original
    end

    it 'should send jobs to the controller worker' do
      expect(app).to receive(:broadcast).with(run_by: 'controller')
      app.worker(:controller, block_until_complete: true).fake
    end

    it 'should send jobs to the default localhost_pod worker' do
      expect(app).to receive(:broadcast).with(run_by: 'localhost_pod')
      app.worker(:optimal_pod, block_until_complete: true).fake
    end

    it 'using :optimal_pod should find the least burdened pod and send a job to it' do
      dockerless_pod = Pod.find_by hostname: 'localhost'
      fabwlus = Fabricate :pod, hostname: 'fabwlus'
      4.times { |i| Fabricate :pea, app: app, pod: dockerless_pod, docker_id: "dp#{i}" }
      3.times { |i| Fabricate :pea, app: app, pod: fabwlus, docker_id: "fp#{i}" }
      WorkerReceiver.new 'fabwlus_pod'
      expect(app).to receive(:broadcast).with(run_by: 'fabwlus_pod')
      app.worker(:optimal_pod, block_until_complete: true).fake
    end
  end

  describe 'Broadcasting messages' do
    it 'should broadcast messages' do
      class App; def fake; 100.times { |i| broadcast i } end end # rubocop:disable Style/SingleLineMethods
      job_listener = client_connection
      job_listener.puts "subscribe.job_progress.#{uuid}"
      app.worker.fake
      statuses = []
      bodies = []
      while (line = JSON.parse(job_listener.gets))
        statuses << line['status']
        bodies << line['body']
        break if line['status'] == 'failed' || line['status'] == 'complete'
      end
      expect(statuses.uniq).to eq ['queued', 'working', 'complete']
      expect(bodies.compact.uniq).to eq((0...100).map(&:to_s))
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
      while (line = JSON.parse(job_listener.gets))
        progress << line
        break if line['status'] == 'complete'
      end
      expect(progress).to include(
        "body" => "it's a long way down",
        "job_id" => "b8d2cdbd6-d3d4-4d2f-8f48-96325a4f2cd6"
      )
    end

    it 'should broadcast to the parent when child is created with a manually set parent job id' do
      Fabricate :pea, app: app
      class App
        def parent_worker
          Pea.first.worker(block_until_complete: true, parent_job_id: parent_job).child_worker
        end
      end
      class Pea
        def child_worker
          broadcast "I was told by the programmer who my parent is"
        end
      end
      parent_job = app.worker(block_until_complete: true).parent_worker
      job_listener = client_connection
      job_listener.puts "subscribe.job_progress.#{parent_job} history"
      progress = []
      while (line = JSON.parse(job_listener.gets))
        progress << line
        break if line['status'] == 'complete'
      end
      expect(progress).to include(
        "body" => "I was told by the programmer who my parent is",
        "job_id" => "b8d2cdbd6-d3d4-4d2f-8f48-96325a4f2cd6"
      )
    end
  end

  describe 'Setting the job id' do
    it 'should set parent and current IDs to be the same for first jobs' do
      job_id = app.worker(block_until_complete: true).fake
      expect(app.parent_job).to eq uuid
      expect(app.current_job).to eq uuid
      expect(job_id).to eq uuid
    end

    it 'should set the parent job id against the model instance if passed as an argument' do
      app.current_job = uuid
      app.worker(block_until_complete: true, parent_job_id: 'manualID').fake
      expect(app.parent_job).to eq 'manualID'
    end

    it "should set a child job's ID with the parent ID and a new job ID" do
      app.current_job = 'currentID'
      app.parent_job = 'parentID'
      allow(App).to receive(:find_by).with(_id: app.id.to_s).and_return(app)
      app.worker(block_until_complete: true).fake
      expect(app.parent_job).to eq 'parentID'
      expect(app.current_job).to eq uuid
    end
  end

  describe "Catching exceptions" do
    it 'should catch exceptions and broadcast them' do
      class App; def badtimes; raise 'HELL!'; end; end # rubocop:disable Style/SingleLineMethods
      expect {
        app.worker(block_until_complete: true).badtimes
      }.to raise_error Peas::ModelWorkerError
      job_listener = client_connection
      job_listener.puts "subscribe.job_progress.#{uuid} history"
      progress = []
      while (line = JSON.parse(job_listener.gets))
        progress << line
        break if line['status'] == 'failed' || line['status'] == 'complete'
      end
      failure_message = progress.delete_if { |p| p['status'] != 'failed' }.first['body']
      expect(failure_message).to match(/HELL! @ .*model_worker_spec.rb.* `badtimes'/)
    end

    it 'should propagate exceptions to parent jobs' do
      class App
        def parent_worker
          worker(block_until_complete: true).child_worker
        end

        def child_worker
          raise 'MOAR HELZ'
        end
      end
      parent_job = app.worker.parent_worker
      job_listener = client_connection
      job_listener.puts "subscribe.job_progress.#{parent_job} history"
      progress = []
      Timeout.timeout(3) do
        while (line = JSON.parse(job_listener.gets))
          progress << line
          break if line['body'] =~ /.*MOAR HELZ.*/
        end
      end
      failure_messages = progress.delete_if { |p| p['status'] != 'failed' }.to_s
      expect(failure_messages).to match(/MOAR HELZ @ .*model_worker_spec.rb.* `child_worker'/)
    end
  end

  describe 'Shell commands' do
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

    it 'should not broadcast ouput when sh() is used' do
      expect(app).to_not receive(:broadcast)
      app.sh 'echo -n "hi"'
    end
  end
end
