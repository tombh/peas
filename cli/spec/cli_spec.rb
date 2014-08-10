require 'spec_helper'

describe 'Peas CLI' do
  before :each do
    allow(Git).to receive(:sh).and_return(nil)
    allow(Git).to receive(:remote).and_return('git@github.com:test-test.git')
    allow_any_instance_of(API).to receive(:sleep).and_return(nil)
    allow(Peas).to receive(:config_file).and_return('/tmp/.peas')
    File.delete '/tmp/.peas' if File.exist? '/tmp/.peas'
  end

  describe 'App name' do
    it 'should get the app name from a remote URI' do
      allow(Git).to receive(:remote).and_return('git@github.com:tombh-peas.git')
      expect(Git.name_from_remote).to eq 'tombh-peas'
    end
  end

  describe 'Settings' do
    it 'should set and use the domain setting' do
      stub_request(:put, 'http://new-domain.com:4000/admin/settings?peas.domain=new-domain.com:4000')
        .to_return(body: response_mock({}))
      expect(Git).to receive(:sh).with("git config peas.domain http://new-domain.com:4000")
      cli %w(admin settings peas.domain new-domain.com:4000)
      config = JSON.parse File.open('/tmp/.peas').read
      expect(config).to eq("domain" => "http://new-domain.com:4000")
    end

    it 'should set a normal setting' do
      stub_request(:put, 'http://vcap.me:4000/admin/settings?mongodb.uri=mongodb://uri')
        .to_return(body: response_mock(
          defaults: { 'peas.domain' => 'http://boss.com' },
          services: {
            'mongodb.uri' => 'mongodb://uri',
            'postgres.uri' => 'xsgfd'
          }
        ))
      output = cli %w(admin settings mongodb.uri mongodb://uri)
      expect(output).to eq("Available settings\n\nDefaults:\n  peas.domain http://boss.com\n\nServices:\n  mongodb.uri mongodb://uri\n  postgres.uri xsgfd\n\n")
    end

  end

  describe 'App methods' do
    it 'should list all apps' do
      stub_request(:get, TEST_DOMAIN + '/app')
        .to_return(body: response_mock(["coolapp"]))
      output = cli ['apps']
      expect(output).to eq "coolapp\n"
    end

    it 'should create an app and its remote' do
      allow(File).to receive(:open).and_call_original
      public_key_path = "#{ENV['HOME']}/.ssh/id_rsa.pub"
      allow(File).to receive(:exist).with(public_key_path).and_return(true)
      allow(File).to receive(:open).with(public_key_path).and_return(double(read: 'apublickey'))
      stub_request(:post, TEST_DOMAIN + '/app?muse=test-test&public_key=apublickey')
        .to_return(
          body: {
            version: Peas::VERSION,
            message: "App 'test-test' successfully created",
            remote_uri: 'git@peas.io:test-test.git'
          }.to_json
        )
      allow(Git).to receive(:remote).with('peas').and_return('')
      allow(Git).to receive(:remote).with('origin').and_return('git@github.com:test-test.git')
      expect(Git).to receive(:add_remote).with('git@peas.io:test-test.git')
      output = cli ['create']
      expect(output).to eq "App 'test-test' successfully created\n"
    end

    it 'should destroy an app' do
      stub_request(:delete, TEST_DOMAIN + '/app/test-test')
        .to_return(body: response_mock("App 'test' successfully destroyed"))
      expect(Git).to receive(:remove_remote)
      output = cli ['destroy']
      expect(output).to eq "App 'test' successfully destroyed\n"
    end

    it 'should scale an app', :with_socket do
      stub_request(
        :put,
        TEST_DOMAIN + '/app/test-test/scale?scaling_hash=%7B%22web%22:%223%22,%22worker%22:%222%22%7D'
      ).to_return(body: '{"job": "123"}')
      allow(@socket).to receive(:gets).and_return(
        '{"body":"scaling"}',
        '{"status":"complete"}'
      )
      output = cli %w(scale web=3 worker=2)
      expect(output).to eq "scaling\n"
    end

    describe 'Config ENV vars' do
      it 'should set config for an app' do
        stub_request(:put, TEST_DOMAIN + '/app/test-test/config?vars=%7B%22FOO%22:%22BAR%22%7D')
          .to_return(body: response_mock("{'FOO' => 'BAR'}"))
        output = cli %w(config set FOO=BAR)
        expect(output).to eq "{'FOO' => 'BAR'}\n"
      end

      it 'delete config for an app' do
        stub_request(:delete, TEST_DOMAIN + '/app/test-test/config?keys=%5B%22FOO%22%5D')
          .to_return(body: response_mock(nil))
        output = cli %w(config rm FOO)
        expect(output).to eq "\n"
      end

      it 'should list all config for an app' do
        stub_request(:get, TEST_DOMAIN + '/app/test-test/config')
          .to_return(body: response_mock("{'FOO' => 'BAR'}\n{'MOO' => 'CAR'}"))
        output = cli %w(config)
        expect(output).to eq "{'FOO' => 'BAR'}\n{'MOO' => 'CAR'}\n"
      end
    end
  end

  describe 'Logs' do
    it 'should stream logs' do
      socket = double 'TCPSocket'
      allow(socket).to receive(:puts)
      allow(socket).to receive(:gets).and_return("Here's ya logs", "MOAR", false)
      allow(TCPSocket).to receive(:new).and_return(socket)
      output = cli %w(logs)
      expect(output).to eq "Here's ya logs\nMOAR\n"
    end
  end

  it 'should retrieve and output a long-running command' do
    socket = double 'TCPSocket'
    expect(socket).to receive(:puts).with('subscribe.job_progress.123')
    allow(socket).to receive(:gets).and_return("doing", "something", "done", false)
    allow(TCPSocket).to receive(:new).and_return(socket)
    expect(API).to receive(:puts).with "doing"
    expect(API).to receive(:puts).with "something"
    expect(API).to receive(:puts).with "done"
    API.stream_output "subscribe.job_progress.123"
  end

  it 'should show a warning when there is a version mismatch' do
    stub_request(:get, TEST_DOMAIN + '/app/test-test/config')
        .to_return(body: '{"version": "100000.1000000.100000"}')
    output = cli %w(config)
    expect(output).to include 'Your version of the CLI client is out of date'
  end
end
