require 'spec_helper'

describe Pea do
  # If recording VCRs for the first time, you will need a docker image called 'node-js-sample'
  let(:app) { Fabricate :app, name: 'node-js-sample' }

  it 'should create a running docker container', :docker do
    pea = Fabricate :pea, app: app, port: nil, docker_id: nil
    pea.spawn_container
    expect(pea.docker.json['State']['Running']).to eq true
    expect(pea.docker.json['Config']['Image']).to eq 'node-js-sample'
    expect(pea.docker.json['Config']['Env']).to include 'PORT=5000'
    expect(pea.docker.json['Config']['Cmd']).to eq ["/bin/bash", "-c", "/start web"]
  end

  it "should parse the container's JSON", :docker do
    pea = Fabricate :pea, app: app, port: nil, docker_id: nil
    pea.spawn_container
    expect(pea.running?).to eq true
    expect(pea.docker_id).to eq pea.docker.info['id']
    expect(pea.port).to eq pea.docker.json['NetworkSettings']['Ports']['5000'].first['HostPort']
  end

  it 'should kill a running container', :docker, :with_worker do
    pea = Fabricate :pea, app: app, port: nil, docker_id: nil
    pea.spawn_container
    expect(pea.running?).to eq true
    docker_id = pea.docker_id
    pea.destroy
    expect{
      Docker::Container.get(docker_id)
    }.to raise_error(Docker::Error::NotFoundError)
    expect(Pea.where(docker_id: docker_id).count).to eq 0
  end
end