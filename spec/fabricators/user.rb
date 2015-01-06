Fabricator :user do
  username 'tombh'
  public_key File.read 'spec/fixtures/ssh_keys/id_rsa.pub'
  api_key 'letmein'
end
