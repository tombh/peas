require 'spec_helper'

describe 'Peas CLI' do
  before :each do
    Git.stub(:sh).and_return(nil)
    Git.stub(:remote).and_return('git@github.com:test/test.git')
    Git.stub(:first_sha).and_return('fakesha')
    API.any_instance.stub(:sleep).and_return(nil)
    Peas.stub(:config_file).and_return('/tmp/.peas')
    File.delete '/tmp/.peas' if File.exists? '/tmp/.peas'
  end

  describe 'Settings' do
    it 'should set settings' do
      stub_request(:put, 'http://new-domain.com:4000/admin/settings?domain=new-domain.com:4000')
        .to_return(body: response_mock(nil))
      output = cli %w(settings --domain=new-domain.com:4000)
      expect(output).to eq "\nNew settings:\n{\n  \"domain\": \"http://new-domain.com:4000\"\n}\n"
      config = JSON.parse File.open('/tmp/.peas').read
      expect(config).to eq({"domain"=>"http://new-domain.com:4000"})
    end

    it 'should use the domain setting' do
      File.open('/tmp/.peas', 'w'){|f| f.write('{"domain":"test.com"}') }
      stub_request(:get, /test.com/)
        .to_return(body: response_mock(nil))
      cli %w(deploy)
    end
  end

  describe 'App methods' do
    it 'should create an app' do
      stub_request(:post, TEST_DOMAIN + '/app/fakesha?remote=git@github.com:test/test.git')
        .to_return(body: response_mock("App 'test' successfully created"))
      output = cli ['create']
      expect(output).to eq "App 'test' successfully created\n"
    end

    it 'should deploy an app' do
      stub_request(:get, /deploy/).to_return(body: '{"job": "123"}')
      stub_request(:get, /status/).to_return(
        {body: '{"status": "working", "output": "deploying\n"}'}
      )
      output = cli ['deploy']
      expect(output).to eq "deploying\n"
    end

    it 'should scale an app' do
      stub_request(
        :put,
        TEST_DOMAIN + '/app/fakesha/scale?scaling_hash=%7B%22web%22:%223%22,%22worker%22:%222%22%7D'
      ).to_return(body: '{"job": "123"}')
      stub_request(:get, /status/).to_return(
        {body: '{"status": "working", "output": "scaling\n"}'}
      )
      output = cli %w(scale web=3 worker=2)
      expect(output).to eq "scaling\n"
    end

    describe 'Config' do
      it 'should set config for an app' do
        stub_request(:put, TEST_DOMAIN + '/app/fakesha/config?vars=%7B%22FOO%22:%22BAR%22%7D')
          .to_return(body: response_mock("{'FOO' => 'BAR'}"))
        output = cli %w(config set FOO=BAR)
        expect(output).to eq "{'FOO' => 'BAR'}\n"
      end

      it 'delete config for an app' do
        stub_request(:delete, TEST_DOMAIN + '/app/fakesha/config?keys=%5B%22FOO%22%5D')
          .to_return(body: response_mock(nil))
        output = cli %w(config rm FOO)
        expect(output).to eq "\n"
      end

      it 'should list all config for an app' do
        stub_request(:get, TEST_DOMAIN + '/app/fakesha/config')
          .to_return(body: response_mock("{'FOO' => 'BAR'}\n{'MOO' => 'CAR'}"))
        output = cli %w(config)
        expect(output).to eq "{'FOO' => 'BAR'}\n{'MOO' => 'CAR'}\n"
      end
    end
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

  it 'should show a warning when there is a version mismatch' do
    stub_request(:get, TEST_DOMAIN + '/app/fakesha/config')
        .to_return(body: '{"version": "100000.1000000.100000"}')
    output = cli %w(config)
    expect(output).to include 'Your version of the CLI client is out of date'
  end
end
