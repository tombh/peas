require 'spec_helper'

describe User do
  it "should add and remove the user's public key from Git's auth file" do
    tmp_key_path = '/tmp/peas/.ssh/authorized_keys.test'
    Peas.sh "echo '' > #{tmp_key_path}"
    stub_const('Peas::GitSSH::AUTHORIZED_KEYS_PATH', tmp_key_path)
    stub_const('Peas::DIND', true)
    user = Fabricate :user
    keys = File.read Peas::GitSSH::AUTHORIZED_KEYS_PATH
    # Get the longest bit which is actually the encoded key
    key_without_meta = keys.strip.split(' ').max_by(&:length)
    expect(key_without_meta).to eq user.public_key
    user.destroy
    keys = File.read Peas::GitSSH::AUTHORIZED_KEYS_PATH
    expect(keys.strip).to eq ''
  end
end
