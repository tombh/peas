require 'spec_helper'

describe App do
  let(:app) { Fabricate :app }

  describe 'deploy()' do
    it 'should trigger a build' do
      expect_any_instance_of(App).to receive(:build)
      Sidekiq::Testing.inline! do
        app.deploy
      end
    end

    it 'should scale web process to 1 if there are no existing containers for the app' do
      allow_any_instance_of(App).to receive(:stream_sh).and_return(true) # Prevent a build
      allow(Sidekiq::Status).to receive(:status).and_return(:complete) # Build completes instantly
      expect_any_instance_of(App).to receive(:scale).with({'web' => 1})
      Sidekiq::Testing.inline! do
        app.deploy
      end
    end

    it "should broadcast the app's URI" do
      allow_any_instance_of(App).to receive(:stream_sh).and_return(true) # Prevent a build
      allow(Sidekiq::Status).to receive(:status).and_return(:complete) # Build completes instantly
      allow_any_instance_of(App).to receive(:scale) # Prevent scaling
      expect_any_instance_of(App).to receive(:broadcast).with(no_args)
      expect_any_instance_of(App).to receive(:broadcast).with(
        /        Deployed to http:\/\/#{app.name}.#{Peas.domain}/
      )
      Sidekiq::Testing.inline! do
        app.deploy
      end
    end

    it 'should not scale web process to 1 if there are existing containers for the app' do
      Fabricate :pea, app: app
      allow_any_instance_of(App).to receive(:stream_sh).and_return(true) # Prevent a build
      allow(Sidekiq::Status).to receive(:status).and_return(:complete) # Build completes instantly
      expect_any_instance_of(App).to_not receive(:scale)
      Sidekiq::Testing.inline! do
        app.deploy
      end
    end
  end

  describe 'build()' do
    it 'should trigger a shell command to buildstep' do
      expect_any_instance_of(App).to(
        receive(:stream_sh).with("bin/buildstep.sh #{app.name} #{app.remote}")
      )
      Sidekiq::Testing.inline! do
        app.deploy
      end
    end
  end

  describe 'scale()' do
    before :each do
      allow(app).to receive(:sh)
    end

    it 'should create peas' do
      allow(app).to receive(:docker_run) { '123112312' }
      allow(app).to receive(:get_docker_port) { '5000' }
      app.scale({web: 3, worker: 2})
      expect(Pea.where(app: app).where(process_type: 'web').count).to eq 3
      expect(Pea.where(app: app).where(process_type: 'worker').count).to eq 2
    end
  end

end
