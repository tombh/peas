require 'spec_helper'
require 'switchboard/server/lib/connection'

Dir["#{Peas.root}/switchboard/clients/**/*.rb"].each { |f| require f }

describe 'Switchboard Pea Commands', :celluloid do

  describe 'Server Commands' do
    describe 'Logs' do

      it 'should receive and write log lines to DB' do
        app = Fabricate :app
        pea = Fabricate :pea, app: app
        with_socket_pair do |client, peer|
          connection = Connection.new(peer)
          client.puts "app_logs.#{pea._id}"
          client.puts 'Been busy and stuff '
          client.puts 'More busy and other stuff '
          connection.dispatch
          sleep 0.2
          logs = app.logs_collection.find.to_a
          expect(logs[0]['line']).to include Date.today.to_s
          expect(logs[1]['line']).to include Date.today.to_s
          expect(logs[0]['line']).to include 'app[web.1]: Been busy and stuff'
          expect(logs[1]['line']).to include 'app[web.1]: More busy and other stuff'
        end
      end

      it 'should stream existing logs from the DB to the client' do
        app = Fabricate :app
        app.log 'Cool story bro', 'testing'
        app.log 'Do you even log?', 'testing'
        with_socket_pair do |client, peer|
          connection = Connection.new(peer)
          client.puts "stream_logs.#{app.name}"
          connection.dispatch
          first = client.gets
          expect(first).to include Date.today.to_s
          expect(first).to include 'app[testing]: Cool story bro'
          second = client.gets
          expect(second).to include Date.today.to_s
          expect(second).to include 'app[testing]: Do you even log?'
        end
      end

      it 'should stream new logs as they are added' do
        app = Fabricate :app
        app.log 'Existing', 'testing'
        with_socket_pair do |client, peer|
          connection = Connection.new(peer)
          client.puts "stream_logs.#{app.name}"
          connection.dispatch
          client.gets
          app.log 'New logs!', 'testing'
          fresh = client.gets
          expect(fresh).to include Date.today.to_s
          expect(fresh).to include 'app[testing]: New logs!'
        end
      end
    end

  end

  describe 'Client Commands' do
    describe LogsArchiver do

      it 'should add a pea to the watch list and remove when finished' do
        app = Fabricate :app
        pea1 = Fabricate :pea, app: app, docker_id: 'pea1'
        pea2 = Fabricate :pea, app: app, docker_id: 'pea2'
        allow(Docker::Container).to receive(:all).and_return([
          double(id: pea1.docker_id),
          double(id: pea2.docker_id),
        ])
        expect(PeaLogsWatcher).to receive(:new).with(pea1).once do |&block|
          block.call
        end
        expect(PeaLogsWatcher).to receive(:new).with(pea2).once do |&block|
          block.call
        end
        actor = LogsArchiver.new
        expect(actor.watched).to eq []
      end
    end

    describe PeaLogsWatcher do
      # Note that when recording you will need an image called 'node-js-sample'
      # And you will also need to manually kill the docker container, or manually abort the
      # blocking container.attach() request. It may be possible to automatically abort by setting
      # a lower limit for READ_TIMEOUT
      before :each do
        @socket = double(TCPSocket)
        allow(TCPSocket).to receive(:new).and_return(@socket)
        allow(@socket).to receive(:close)
        allow(@socket).to receive(:puts).with('')
        allow(@socket).to receive(:puts).with(any_args)
        @app = Fabricate :app, name: 'node-js-sample'
        @pea = Fabricate :pea, app: @app, port: nil, docker_id: nil
        @pea.spawn_container
      end

      it 'should stream the logs for a pea', :docker do
        expect(@socket).to receive(:puts).with("app_logs.#{@pea._id}")
        expect(@socket).to receive(:puts).with('> node-js-sample@0.1.0 start /app')
        PeaLogsWatcher.new @pea
      end

      it 'should wait for a pea to boot before connecting', :docker do
        allow(@pea).to receive(:running?).and_return(false, true)
        allow_any_instance_of(PeaLogsWatcher).to receive(:info).with(/Starting to watch/)
        expect_any_instance_of(PeaLogsWatcher).to receive(:info).with(/Waiting for/)
        allow(@socket).to receive(:puts).with(any_args)
        expect(@socket).to receive(:puts).with('Node app is running at localhost:5000')
        PeaLogsWatcher.new @pea
      end
    end
  end

end
