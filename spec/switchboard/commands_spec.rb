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
          client.puts "stream_logs.#{app.name} follow"
          connection.dispatch
          client.gets
          app.log 'New logs!', 'testing'
          fresh = client.gets
          expect(fresh).to include Date.today.to_s
          expect(fresh).to include 'app[testing]: New logs!'
        end
      end
    end

    describe 'Pubsub' do
      # A little word about these sleeps, they're bad m'kay
      # I suspect what's happening is that because the subscribe and publish processes are
      # running as separate celluloid threads they need to be forced to execute in the order
      # that is implied in this spec. The order isn't always honoured otherwise. Worth considering
      # the implications of this for production code.

      # Also, not sure why these don't use with_socket_pair{}

      before :each do
        @server = switchboard_server
        sleep 0.05
        @client = client_connection
      end

      it 'should publish and broadcast to 2 subscribers' do
        listener1 = client_connection
        listener2 = client_connection
        listener1.puts 'subscribe.test'
        listener2.puts 'subscribe.test'
        sleep 0.05
        @client.puts 'publish.test'
        @client.puts 'foo'
        sleep 0.05
        expect(listener1.gets.strip).to eq 'foo'
        expect(listener2.gets.strip).to eq 'foo'
      end

      it "should not keep history when history isn't specified" do
        @client.puts 'publish.test'
        @client.puts 'forgetme'
        sleep 0.05
        listener = client_connection
        listener.puts 'subscribe.test'
        sleep 0.05
        @client.puts 'foo'
        expect(listener.gets.strip).to eq 'foo'
      end

      it 'should keep history when history is specified' do
        @client.puts 'publish.test history'
        @client.puts 'rememberme'
        @client.puts 'foo'
        listener = client_connection
        listener.puts 'subscribe.test history'
        expect(listener.gets.strip).to eq 'rememberme'
        expect(listener.gets.strip).to eq 'foo'
      end
    end

    describe 'TTY', :with_worker do
      let(:app) { Fabricate :app }

      after(:each) { app.peas.destroy_all }

      it 'should create a remote pea', :docker do
        allow_any_instance_of(Pea).to receive(:destroy)
        with_socket_pair do |client, peer|
          connection = Connection.new(peer)
          client.puts "tty.#{app.name}"
          connection.dispatch
          client.puts "ls"
          # Wait up to 5 secs for the container to boot
          Timeout.timeout(5) do
            sleep 0.1 until app.peas.count == 1
            sleep 0.1 while app.peas.first.pod.nil?
          end
          command = app.peas.first.command
          expect(command).to match(/cd \/app.*profile.*ls$/)
          expect(app.peas.first.docker.json['Config']['Cmd']).to eq ['/bin/bash', '-c', command]
        end
      end

      it 'should destroy the pea after a socket closes', :docker do
        with_socket_pair do |client, peer|
          # Try not to destroy the container straight away!
          allow_any_instance_of(Docker::Container).to receive(:attach).and_yield { sleep 0.1 }
          expect_any_instance_of(Docker::Container).to receive(:delete)
          connection = Connection.new(peer)
          client.puts "tty.#{app.name}"
          connection.dispatch
          client.puts "ls"
          # Wait up to 5 secs for the container to boot
          Timeout.timeout(5) do
            sleep 0.1 until Pea.count == 1
          end
          # Wait up to 5 secs for the container to be removed
          Timeout.timeout(5) do
            sleep 0.1 until Pea.count == 0
          end
        end
      end

      context 'Rendevous connection' do
        include_context :docker_creation_mock

        it 'created pea should connect to a client socket via rendevous' do
          allow_any_instance_of(Pea).to receive(:destroy)
          container = instance_double(Docker::Container)
          allow_any_instance_of(Pea).to receive(:docker).and_return(container)
          allow(container).to receive(:start)
          allow(container).to receive(:kill)
          allow(container).to receive(:delete)
          # This block simulates a container outputting through STDOUT
          allow(container).to receive(:attach) do |*args, &block|
            input = args.first[:stdin].gets.strip
            block.call "WOW #{input} TURNED INTO OUTPUT"
          end
          server_actor = Celluloid::Actor[:switchboard_server]
          with_socket_pair do |client, peer|
            connection = Connection.new(peer)
            client.puts "tty.#{app.name}"
            connection.dispatch
            client.puts "ls"
            client.puts "INPUT"
            # Wait up to 5 secs for the worker to create the container mock
            Timeout.timeout(5) do
              sleep 0.1 until Pea.count == 1 && server_actor.rendevous.keys.count == 1
            end
            rendevous_socket = server_actor.rendevous[server_actor.rendevous.keys.first]
            expect(rendevous_socket.gets).to eq 'WOW INPUT TURNED INTO OUTPUT'
          end
        end
      end

    end

    describe 'Admin TTY' do
      it 'should shell out to the command line' do
        with_socket_pair do |client, peer|
          connection = Connection.new(peer)
          client.puts "admin_tty"
          connection.dispatch
          client.puts "echo REKT"
          client.gets
          expect(client.gets.strip).to eq 'REKT'
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
          double(id: pea2.docker_id)
        ])
        done = []
        expect(PeaLogsWatcher).to receive(:new).with(pea1).once do |&block|
          block.call
          done << 'pea1'
        end
        expect(PeaLogsWatcher).to receive(:new).with(pea2).once do |&block|
          block.call
          done << 'pea2'
        end
        actor = LogsArchiver.new
        expect(actor.watched).to eq []
        sleep 0.05 until done.count == 2
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
        @container = @pea.spawn_container
      end

      it 'should stream the logs for a pea', :docker do
        expect(@socket).to receive(:puts).with('> node-js-sample@0.1.0 start /app')
        if VCR.current_cassette.originally_recorded_at.nil?
          Thread.new do
            sleep 1
            @container.kill
            @container.delete
          end
        end
        PeaLogsWatcher.new @pea
      end

      it 'should wait for a pea to boot before connecting', :docker do
        allow(@pea).to receive(:running?).and_return(false, true)
        allow_any_instance_of(PeaLogsWatcher).to receive(:info).with(/Starting to watch/)
        expect_any_instance_of(PeaLogsWatcher).to receive(:info).with(/Waiting for/)
        allow(@socket).to receive(:puts).with(any_args)
        expect(@socket).to receive(:puts).with('> node-js-sample@0.1.0 start /app')
        if VCR.current_cassette.originally_recorded_at.nil?
          Thread.new do
            sleep 1
            @container.kill
            @container.delete
          end
        end
        PeaLogsWatcher.new @pea
      end
    end
  end

end
