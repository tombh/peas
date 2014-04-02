require 'spec_helper'

describe 'Peas CLI' do
  before :each do
    Git.any_instance.stub(:sh).and_return(nil)
    Git.any_instance.stub(:remote).and_return('git@github.com:test/test.git')
    API.any_instance.stub(:sleep).and_return(nil)
  end

  it 'should create an app' do
    stub_request(:post, /create\?repo=git@github\.com:test\/test\.git/)
      .to_return(body: '{"test": "this"}')
    output = cli ['create']
    expect(output).to eq "{\"test\": \"this\"}\n"
  end

  it 'should deploy an app' do
    stub_request(:get, /deploy/).to_return(body: '{"test": "this"}')
    output = cli ['deploy']
    expect(output).to eq "{\"test\": \"this\"}\n"
  end

  it 'should retrieve a job status for a long-running command' do
    stub_request(:get, /deploy/).to_return(body: '{"job": "123"}')
    stub_request(:get, /status/).to_return(body: '{"status": "complete", "output": "done"}')
    output = cli ['deploy']
    expect(output).to eq "done\n"
  end
end
