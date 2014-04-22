Vagrant.configure('2') do |config|
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "raring64-daily"

  # Built 25-Jan-2014 04:11
  config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/raring/current/raring-server-cloudimg-amd64-vagrant-disk1.box"

  # Avahi-daemon will broadcast the server's address as peas.local
  config.vm.host_name = "peas"

  # IP will be associated to 'peas.local' using avahi-daemon
  config.vm.network :private_network, ip: "192.168.61.100"

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "1024"]

    # Displays a friendly name in the VirtualBox GUI
    vb.name = "peas"
  end

  config.vm.provision :shell, inline: <<-SCRIPT
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
    sudo sh -c "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
    sudo apt-get update && sudo apt-get upgrade
    sudo apt-get install -yq \
      avahi-daemon \
      git \
      lxc-docker \
      mongodb \
      redis-server \
      ruby1.9.1-dev \
      libssl-dev
    # Redis might boot before networking, so get it to start later during boot
    sudo update-rc.d redis-server remove
    sudo update-rc.d redis-server start 80 2 3 4 5 . stop 20 0 1 6 .
    sudo gpasswd -a vagrant docker
    sudo su - vagrant
    docker pull progrium/buildstep
    gem install bundler
    git clone https://github.com/tombh/peas.git
    cd peas && bundle install
  SCRIPT
end
