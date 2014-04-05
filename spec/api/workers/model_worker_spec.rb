require 'spec_helper'

describe ModelWorker do
  let(:app) { Fabricate :app }

  before :each do
    App.any_instance.stub(:deploy).and_return(:success)
  end

  describe "Calling the model's method" do
    it 'should instantiate the correct model object' do
      App.should_receive(:where).with({_id: app.id.to_s}).and_return([app])
      ModelWorker.new.perform 'App', app.id.to_s, :deploy
    end

    it 'should call the correct method with the given arguments on the passed model' do
      App.any_instance.should_receive(:deploy).with('argument', :more)
      ModelWorker.new.perform 'App', app.id.to_s, :deploy, 'argument', :more
    end
  end

  describe 'Setting the job id' do
    it 'should not propogate the job id as an arg to the called worker method' do
      App.any_instance.should_receive(:deploy).with(:arg)
      ModelWorker.new.perform 'App', app.id.to_s, :deploy, :arg, {'job' => '123'}
    end

    it 'should set the job id against the model instance if passed as an argument' do
      App.any_instance.should_receive(:job=).with('123')
      ModelWorker.new.perform 'App', app.id.to_s, :deploy, :arg, {'job' => '123'}
    end

    it 'should set the Sidekiq job id and propagate it if no job id passed as an argument' do
      worker = ModelWorker.new
      App.any_instance.should_receive(:job=).with(worker.jid)
      ModelWorker.new.perform 'App', app.id.to_s, :deploy
    end
  end

  describe "Catching exceptions" do
    it 'should catch exceptions in development and log and broadcast them' do
      Peas.stub(:environment).and_return('development')
      ModelWorker.any_instance.stub_chain(:logger, :error)
      ModelWorker.any_instance.stub_chain(:logger, :debug)
      ModelWorker.any_instance.should_receive(:logger)
      Sidekiq::Status.should_receive(:broadcast)
      ModelWorker.new.perform 'App', app.id.to_s, :non_existent_method
    end

    it 'should propagate exceptions in non development environments' do
      expect {
        ModelWorker.new.perform 'App', app.id.to_s, :non_existent_method
      }.to raise_error
    end
  end
end
