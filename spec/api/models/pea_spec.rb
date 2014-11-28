require 'spec_helper'

describe Pea, :docker, :with_worker do
  let(:app) {
    node_app = Fabricate :app, name: 'node-js-sample'
    # If recording VCRs for the first time, we'll need a docker image called 'node-js-sample'
    if VCR.current_cassette.originally_recorded_at.nil?
      unless Docker::Image.exist? 'node-js-sample'
        puts "Sample NodeJS image doesn't exist, building..."
        create_non_bare_repo 'nodejs', node_app.local_repo_path
        node_app.worker(block_until_complete: true).build 'HEAD'
      end
    end
    node_app
  }

  it 'should create a running docker container' do
    pea = Fabricate :pea, app: app, port: nil, docker_id: nil
    pea.spawn_container
    expect(pea.docker.json['State']['Running']).to eq true
    expect(pea.docker.json['Config']['Image']).to eq 'node-js-sample'
    expect(pea.docker.json['Config']['Env']).to include 'PORT=5000'
    expect(pea.docker.json['Config']['Cmd']).to eq ["/bin/bash", "-c", "/start web"]
  end

  it "should parse the container's JSON" do
    pea = Fabricate :pea, app: app, port: nil, docker_id: nil
    pea.spawn_container
    expect(pea.running?).to eq true
    expect(pea.docker_id).to eq pea.docker.info['id']
    expect(pea.port).to eq pea.docker.json['NetworkSettings']['Ports']['5000'].first['HostPort']
  end

  it 'should kill a running container', :with_worker do
    pea = Fabricate :pea, app: app, port: nil, docker_id: nil
    pea.spawn_container
    expect(pea.running?).to eq true
    docker_id = pea.docker_id
    pea.destroy
    expect {
      Docker::Container.get(docker_id)
    }.to raise_error(Docker::Error::NotFoundError)
    expect(Pea.where(docker_id: docker_id).count).to eq 0
  end
end
