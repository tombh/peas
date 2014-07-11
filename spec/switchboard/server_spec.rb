require 'spec_helper'
require 'switchboard/server/lib/switchboard_server'

describe 'Switchboard', :celluloid do

  describe SwitchboardServer do
    before :each do
      @server = switchboard_server
      sleep 0.05
      @client = client_connection
    end

    it 'should accept a basic connection' do
      @client.puts 'ping'
      expect(@client.gets.strip).to eq 'pong'
    end

    it 'should accept multiple simultaneous connections' do
      second = client_connection
      @client.puts 'echo'
      second.puts 'echo'
      @client.puts 'foo'
      expect(@client.gets.strip).to eq 'foo'
      second.puts 'bar'
      expect(second.gets.strip).to eq 'bar'
      second.close
    end

    describe 'Pubsub' do
      it 'should publish and broadcast to 2 subscribers' do
        listener1 = client_connection
        listener2 = client_connection
        listener1.puts 'subscribe.test'
        listener2.puts 'subscribe.test'
        @client.puts 'publish.test'
        @client.puts 'foo'
        expect(listener1.gets.strip).to eq 'foo'
        expect(listener2.gets.strip).to eq 'foo'
      end

      it "should not keep history when history isn't specified" do
        # A little word about these sleeps, they're bad m'kay
        # I suspect what's happending is that because the subscribe and publish processes are
        # are running as separate celluloid threads they need to be forced to execute in the order
        # that is implied in this spec. The order isn't always honoured otherwise. Worth considering
        # the implications of this for production code.
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

    context 'should not leak tasks' do
      it 'for non-errored connections' do
        50.times do
          # Use the client_connection() method to create a new socket for every iteration
          client_connection.puts 'fake'
        end
        sleep 0.3
        expect(@server.tasks.count).to eq 3
      end
      it 'for errored connections' do
        50.times do
          client_connection.puts 'raise_exception'
        end
        sleep 0.3
        expect(@server.tasks.count).to eq 3
      end
    end

    it 'should not crash if a connection actor crashes' do
      @client.puts 'raise_exception'
      second = client_connection
      second.puts 'ping'
      expect(second.gets.strip).to eq 'pong'
    end
  end

  describe Connection do
    it 'should read a header and call the relevant method' do
      with_socket_pair do |client, peer|
        connection = Connection.new(peer)
        expect(connection.wrapped_object).to receive(:fake)
        client.puts 'fake.foo.bar'
        connection.dispatch
      end
    end

    it 'should not call native ruby instance methods' do
      with_socket_pair do |client, peer|
        connection = Connection.new(peer)
        expect(connection.wrapped_object).to_not receive(:call)
        expect(connection.wrapped_object).to receive(:warn).with(/Uknown command/)
        client.puts 'call'
        connection.dispatch
      end
    end

    it 'should detect a closed client connection' do
      with_socket_pair do |client, peer|
        allow(peer).to receive(:puts).and_raise(EOFError)
        connection = Connection.new(peer)
        expect(connection.wrapped_object).to receive(:close).with(:detected)
        client.puts 'ping'
        connection.dispatch
      end
    end

    describe 'Watching and responding to activity/inactivity' do
      it 'should close a long running connection after an inactivity timeout' do
        module Commands
          def dose; sleep @command[1].to_i / 1000; end
        end
        with_socket_pair do |client, peer|
          stub_const('Connection::INACTIVITY_TIMEOUT', 0.001)
          connection = Connection.new(peer)
          expect(connection.wrapped_object).to receive(:terminate).at_least(:once)
          client.puts 'dose.1000' # Sleep for 1 second
          connection.dispatch
          sleep 0.01
        end
      end

      it 'io activity prevents timeout' do
        module Commands
          def keep_awake; 10.times{ write_line 'foo'; sleep 0.0005 }; end
        end
        with_socket_pair do |client, peer|
          stub_const('Connection::INACTIVITY_TIMEOUT', 0.001)
          connection = Connection.new(peer)
          expect(connection.wrapped_object).to_not receive(:terminate)
          client.puts 'keep_awake'
          connection.dispatch
        end
      end
    end
  end
end