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
        conn_double = instance_double Connection
        allow(connection).to receive(:async).and_return(conn_double)
        expect(conn_double).to receive(:send).with('fake')
        client.puts Setting.retrieve 'peas.switchboard_key'
        client.puts 'fake.foo.bar'
        connection.dispatch
      end
    end

    it 'should not call native ruby instance methods' do
      with_socket_pair do |client, peer|
        connection = Connection.new(peer)
        expect(connection.wrapped_object).to_not receive(:call)
        expect(connection.wrapped_object).to receive(:warn).with(/Uknown command/)
        client.puts Setting.retrieve 'peas.switchboard_key'
        client.puts 'call'
        connection.dispatch
      end
    end

    it 'should detect a closed client connection' do
      with_socket_pair do |_client, peer|
        allow(peer).to receive(:puts).and_raise(EOFError)
        connection = Connection.new(peer)
        expect(connection.wrapped_object).to receive(:close).with(:detected)
        connection.ping
      end
    end

    describe 'Watching and responding to activity/inactivity' do
      it 'should close a long running connection after an inactivity timeout' do
        module Commands
          def dose
            sleep 1
          end
        end
        with_socket_pair do |_client, peer|
          stub_const('Connection::INACTIVITY_TIMEOUT', 0.001)
          connection = Connection.new(peer)
          expect(connection.wrapped_object).to receive(:inactivity_callback)
          connection.close
        end
      end

      it 'io activity prevents timeout' do
        module Commands
          def keep_awake
            10.times {
              write_line 'foo'
              sleep 0.05
            }
          end
        end
        with_socket_pair do |_client, peer|
          stub_const('Connection::INACTIVITY_TIMEOUT', 0.1)
          connection = Connection.new(peer)
          expect(connection.wrapped_object).to_not receive(:inactivity_callback)
          connection.keep_awake
        end
      end

      it 'should keep a connection alive if the command sets @keep_alive to true' do
        module Commands
          def keep_alive
            @keep_alive = true
            sleep 0.2
          end
        end
        with_socket_pair do |_client, peer|
          stub_const('Connection::INACTIVITY_TIMEOUT', 0.1)
          connection = Connection.new(peer)
          expect(connection.wrapped_object).to_not receive(:terminate)
          connection.keep_alive
        end
      end
    end
  end
end
