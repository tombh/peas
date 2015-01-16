require 'spec_helper'

describe 'Peas CLI' do
  before :each do
    allow(Git).to receive(:sh).and_return(nil)
    allow(Git).to receive(:remote).and_return('git@github.com:test-test.git')
    allow_any_instance_of(API).to receive(:sleep).and_return(nil)
    allow_any_instance_of(API).to receive(:api_key).and_return 'APIKEY'
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
      stub_request(:put, 'https://new-domain.com:4000/admin/settings?peas.domain=new-domain.com:4000')
        .with(headers: { 'X-Api-Key' => 'APIKEY' })
        .to_return(body: response_mock)
      expect(Git).to receive(:sh).with("git config peas.domain https://new-domain.com:4000")
      cli %w(admin settings peas.domain new-domain.com:4000)
      config = JSON.parse File.open('/tmp/.peas').read
      expect(config).to eq("domain" => "https://new-domain.com:4000")
    end

    it 'should set a normal setting' do
      stub_request(:put, TEST_DOMAIN + '/admin/settings?mongodb.uri=mongodb://uri')
        .with(headers: { 'X-Api-Key' => 'APIKEY' })
        .to_return(body: response_mock(
          defaults: { 'peas.domain' => 'https://boss.com' },
          services: {
            'mongodb.uri' => 'mongodb://uri',
            'postgres.uri' => 'xsgfd'
          }
        ))
      output = cli %w(admin settings mongodb.uri mongodb://uri)
      expect(output).to eq("Available settings\n\nDefaults:\n  peas.domain https://boss.com\n\nServices:\n  mongodb.uri mongodb://uri\n  postgres.uri xsgfd\n\n")
    end

  end

  describe 'App methods' do
    it 'should list all apps' do
      stub_request(:get, TEST_DOMAIN + '/app')
        .with(headers: { 'X-Api-Key' => 'APIKEY' })
        .to_return(body: response_mock(["coolapp"]))
      output = cli ['apps']
      expect(output).to eq "coolapp\n"
    end

    it 'should create an app and its remote' do
      public_key_path = "#{ENV['HOME']}/.ssh/id_rsa.pub"
      allow(File).to receive(:open).and_call_original
      expect(File).to receive(:exist?).with(public_key_path) { true }
      expect(File).to receive(:open).with(public_key_path) { double(read: 'apublickey') }
      stub_request(:post, TEST_DOMAIN + '/app?muse=test-test&public_key=apublickey')
        .with(headers: { 'X-Api-Key' => 'APIKEY' })
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
        .with(headers: { 'X-Api-Key' => 'APIKEY' })
        .to_return(body: response_mock("App 'test' successfully destroyed"))
      expect(Git).to receive(:remove_remote)
      output = cli ['destroy']
      expect(output).to eq "App 'test' successfully destroyed\n"
    end

    it 'should scale an app', :with_socket do
      expect(@socket).to receive(:puts).with('subscribe.job_progress.123')
      expect(@socket).to receive(:puts).with "APIKEY"
      stub_request(
        :put,
        TEST_DOMAIN + '/app/test-test/scale?scaling_hash=%7B%22web%22:%223%22,%22worker%22:%222%22%7D'
      )
        .with(headers: { 'X-Api-Key' => 'APIKEY' })
        .to_return(body: '{"job": "123"}')
      allow(@socket).to receive(:gets).and_return(
        'AUTHORISED',
        '{"body":"scaling"}',
        '{"status":"complete"}'
      )
      output = cli %w(scale web=3 worker=2)
      expect(output).to eq "scaling\n"
    end

    describe 'Running one-off commands', :with_echo_server do
      it 'should run one-off commands direct from the CLI' do
        output = cli %w(run FINAL COMMAND)
        expect(output).to eq "tty.test-test\nFINAL COMMAND\n"
      end
      # This one has taken me soooooo long to figure out. This is testing the ability to open up
      # an SSH-like TTY, that among other things will let you interact with ncurses programs like
      # VIM. So it's important that the duplex (simultaneous read/write) connections are tested.
      it 'should run one-off commands with input from STDIN' do
        # Using a pipe rather than a plain string means that no EOF is sent, which prematurely
        # closes the connection.
        read, write = IO.pipe
        write.write "FINAL COMMAND\n"
        # Stub the pipe into STDIN.raw to simulate typing
        allow(STDIN).to receive(:raw) do |&block|
          block.call read
        end
        output = cli %w(run WITH STDIN)
        expect(output).to eq "tty.test-test\nWITH STDIN\nFINAL COMMAND\n"
      end
    end

    describe 'Config ENV vars' do
      it 'should set config for an app' do
        stub_request(:put, TEST_DOMAIN + '/app/test-test/config?vars=%7B%22FOO%22:%22BAR%22%7D')
          .with(headers: { 'X-Api-Key' => 'APIKEY' })
          .to_return(body: response_mock("{'FOO' => 'BAR'}"))
        output = cli %w(config set FOO=BAR)
        expect(output).to eq "{'FOO' => 'BAR'}\n"
      end

      it 'delete config for an app' do
        stub_request(:delete, TEST_DOMAIN + '/app/test-test/config?keys=%5B%22FOO%22%5D')
          .with(headers: { 'X-Api-Key' => 'APIKEY' })
          .to_return(body: response_mock(nil))
        output = cli %w(config rm FOO)
        expect(output).to eq "\n"
      end

      it 'should list all config for an app' do
        stub_request(:get, TEST_DOMAIN + '/app/test-test/config')
          .with(headers: { 'X-Api-Key' => 'APIKEY' })
          .to_return(body: response_mock("{'FOO' => 'BAR'}\n{'MOO' => 'CAR'}"))
        output = cli %w(config)
        expect(output).to eq "{'FOO' => 'BAR'}\n{'MOO' => 'CAR'}\n"
      end
    end
  end

  describe 'Logs' do
    it 'should stream logs', :with_socket do
      expect(@socket).to receive(:puts).with('stream_logs.test-test')
      expect(@socket).to receive(:puts).with "APIKEY"
      allow(@socket).to receive(:gets).and_return(
        "AUTHORISED",
        "Here's ya logs",
        "MOAR",
        false
      )
      output = cli %w(logs)
      expect(output).to eq "Here's ya logs\nMOAR\n"
    end
  end

  it 'should retrieve and output a long-running command', :with_socket do
    expect(@socket).to receive(:puts).with('subscribe.job_progress.123')
    expect(@socket).to receive(:puts).with "APIKEY"
    allow(@socket).to receive(:gets).and_return(
      "AUTHORISED",
      "doing",
      "something",
      "done",
      false
    )
    expect(API).to receive(:puts).with "doing"
    expect(API).to receive(:puts).with "something"
    expect(API).to receive(:puts).with "done"
    API.stream_output "subscribe.job_progress.123"
  end

  it 'should show a warning when there is a version mismatch' do
    stub_request(:get, TEST_DOMAIN + '/app/test-test/config')
      .with(headers: { 'X-Api-Key' => 'APIKEY' })
      .to_return(body: '{"version": "100000.1000000.100000"}')
    output = cli %w(config)
    expect(output).to include 'Your version of the CLI client is out of date'
  end
end
