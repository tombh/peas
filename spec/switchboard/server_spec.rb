require 'spec_helper'
require 'switchboard/server/lib/switchboard_server'

describe SwitchboardServer do
  let(:client){ TCPSocket.new 'localhost', 79345 }

  before :each do
    Celluloid.boot
    @supervisor = SwitchboardServer.new 'localhost', 79345
  end

  after :each do
    client.close
    Celluloid.shutdown
  end

  it 'should accept connections' do
    expect(Connection).to receive(:new)
    client.puts 'foo'
    expect(@supervisor.tasks.count).to eq 2
  end
end