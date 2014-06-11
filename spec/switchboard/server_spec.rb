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

    it 'should close a long running connection after an inactivity timeout' do
      with_socket_pair do |client, peer|
        stub_const('Connection::INACTIVITY_TIMEOUT', 0.001)
        connection = Connection.new(peer)
        expect(connection.wrapped_object).to receive(:terminate)
        client.puts 'dose.1000' # Sleep for 1 second
        connection.async.dispatch
        sleep 0.01
      end
    end
  end
end