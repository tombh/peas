require 'spec_helper'
require 'switchboard/server/lib/switchboard_server'

describe SwitchboardServer do

  before :each do
    Celluloid.boot
  end

  after :each do
    Celluloid.shutdown
  end

  it 'should accept connections' do
    server = SwitchboardServer.new 'localhost', 79345
    client = TCPSocket.new 'localhost', 79345
    expect(Connection).to receive(:new)
    client.puts 'foo'
    expect(server.tasks.count).to eq 2
    client.close
  end

  describe Connection do
    it 'should read a header and call the relevant method' do
      # Circumvent the dynamic method-calling sanity check for the stubbed :fake method
      allow(Commands).to receive(:instance_methods).and_return([:fake])

      with_socket_pair do |client, peer|
        connection = Connection.new(peer)
        bare = connection.wrapped_object
        bare.instance_eval do
           def fake(); end
        end
        expect(bare).to receive(:fake)
        client.puts 'fake.foo.bar'
        connection.dispatch
      end
    end
  end
end