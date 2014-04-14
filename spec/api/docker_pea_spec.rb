require 'spec_helper'

describe DockerPea do

  describe 'Running a pea', :docker do

    it 'should create a running docker container' do
      pea = DockerPea.run 'peas', 'web'
      expect(pea.docker.json['State']['Running']).to eq true
      expect(pea.docker.json['Config']['Image']).to eq 'peas'
      expect(pea.docker.json['Config']['Env']).to eq ['PORT=5000']
      expect(pea.docker.json['Config']['Cmd']).to eq ["/bin/bash", "-c", "/start web"]
    end

    it "should parse the container's JSON" do
      pea = DockerPea.run 'peas', 'web'
      expect(pea.running?).to eq true
      expect(pea.id).to eq pea.docker.info['id']
      expect(pea.port).to eq pea.docker.json['NetworkSettings']['Ports']['5000'].first['HostPort']
    end
  end
end