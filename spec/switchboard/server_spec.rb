require 'spec_helper'
require 'switchboard/server/lib/switchboard_server'

describe 'Switchboard' do

  before :each do
    Celluloid.boot
  end

  after :each do
    Celluloid.shutdown
  end

  describe SwitchboardServer do
    before :each do
      @server = SwitchboardServer.new SWITCHBOARD_TEST_HOST, SWITCHBOARD_TEST_PORT
      sleep 0.05
      @client = client_connection
    end

    after :each do
      @client.close
      @server.terminate
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

    context 'should not leak tasks' do
      it 'for non-errored connections' do
        100.times do
          # Use the client_connection() method to create a new socket for every iteration
          client_connection.puts 'fake'
        end
        sleep 0.1
        expect(@server.tasks.count).to eq 3
      end
      it 'for errored connections' do
        100.times do
          client_connection.puts 'raise_exception'
        end
        sleep 0.1
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
        # Allow close() to be called without args in the ensure block in dispatch()
        allow(connection.wrapped_object).to receive(:close).with(no_args())
        expect(connection.wrapped_object).to receive(:close).with(:detected)
        client.puts 'ping'
        connection.dispatch
      end
    end

    describe 'Watching and responding to activity/inactivity' do
      it 'should close a long running connection after an inactivity timeout' do
        module Commands
          def dose; sleep @header[1].to_i / 1000; end
        end
        with_socket_pair do |client, peer|
          stub_const('Connection::INACTIVITY_TIMEOUT', 0.001)
          connection = Connection.new(peer)
          expect(connection.wrapped_object).to receive(:terminate)
          client.puts 'dose.1000' # Sleep for 1 second
          connection.dispatch
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