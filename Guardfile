guard 'bundler' do
  watch('Gemfile')
end

group :server do
  guard :shotgun, port: ENV['PORT'] do
    watch(/.+/) # watch *every* file in the directory
  end
end
