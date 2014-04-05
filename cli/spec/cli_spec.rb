require 'spec_helper'

describe 'Peas CLI' do
  before :each do
    Git.any_instance.stub(:sh).and_return(nil)
    Git.any_instance.stub(:remote).and_return('git@github.com:test/test.git')
    Git.any_instance.stub(:first_sha).and_return('fakesha')
    API.any_instance.stub(:sleep).and_return(nil)
  end

  it 'should create an app' do
    stub_request(:post, /create\?first_sha=fakesha&remote=git@github\.com:test\/test\.git/)
      .to_return(body: '{"message": "App \'test\' successfully created\n"}')
    output = cli ['create']
    expect(output).to eq "App 'test' successfully created\n"
  end

  it 'should deploy an app' do
    stub_request(:get, /deploy/).to_return(body: '{"message": "deployed"}')
    output = cli ['deploy']
    expect(output).to eq "deployed\n"
  end

  it 'should retrieve and output a long-running command' do
    stub_request(:get, /deploy/).to_return(body: '{"job": "123"}')
    stub_request(:get, /status/).to_return(
      {body: '{"status": "working", "output": "doing\n"}'},
      {body: '{"status": "working", "output": "doing\nsomething\n"}'},
      {body: '{"status": "working", "output": "doing\nsomething\n"}'},
      {body: '{"status": "complete", "output": "doing\nsomething\ndone\n"}'}
    )
    output = cli ['deploy']
    expect(output).to eq "doing\nsomething\ndone\n"
  end
end
