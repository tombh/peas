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

    it 'should accept a connection' do
      expect(Connection).to receive(:new)
      @client.puts 'fake'
    end

    it 'should accept multiple simultaneous connections' do
      second = client_connection
      @client.puts 'echo'
      second.puts 'echo'
      @client.puts 'foo'
      expect(@client.gets).to eq "foo\n"
      second.puts 'bar'
      expect(second.gets).to eq "bar\n"
      second.close
    end

    it 'should not leak tasks' do
      100.times do
        # Use the client_connection() method to create a new socket for every iteration
        client_connection.puts 'fake'
      end
      sleep 0.1
      expect(@server.tasks.count).to eq 3
    end

    it 'should not inherit exceptions from the connection actor' do
      @client.puts 'raise_exception'
      # expect { @client.puts 'raise_exception' }.to_not raise_error
    end
  end


  it 'should read a header and call the relevant method' do
    with_socket_pair do |client, peer|
      connection = Connection.new(peer).wrapped_object
      expect(connection).to receive(:fake)
      client.puts 'fake.foo.bar'
      connection.dispatch
    end
  end
end