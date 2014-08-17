# Inspired by @jpetazzo's Docker in Docker: https://github.com/jpetazzo/dind

FROM ubuntu:14.04
MAINTAINER tom@tombh.co.uk

# General Peas deps
RUN apt-get update
RUN apt-get install -qqy software-properties-common
RUN apt-add-repository ppa:brightbox/ruby-ng -y
RUN apt-get update
RUN apt-get install -qqy ruby2.1 ruby2.1-dev build-essential libssl-dev libpq-dev

# Mongo DB
# Add 10gen official apt source to the sources list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
RUN echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | tee /etc/apt/sources.list.d/10gen.list
# Hack for initctl not being available in Ubuntu
RUN dpkg-divert --local --rename --add /sbin/initctl
# Install mongo
RUN apt-get update
RUN apt-get install -qqy mongodb-org=2.6.3
# Create the MongoDB data directory
RUN mkdir -p /data/db

# Peas-specific deps
RUN useradd -d /home/peas peas
RUN chsh -s /bin/bash peas
ADD ./ /home/peas/repo
RUN echo "export GEM_HOME=/home/peas/.bundler" > /home/peas/.profile
RUN echo "export PATH=$PATH:/home/peas/.bundler/bin" >> /home/peas/.profile
RUN chown -R peas /home/peas
RUN gem install bundler
# Create a Git server
RUN apt-get install -qqy openssh-server
RUN useradd -d /home/git git
# Make the primary group for git the peas group, so all files it creates have the peas group
RUN usermod -g peas git
RUN gpasswd -a git peas

# DinD magic
RUN apt-get install -qqy iptables ca-certificates lxc
RUN apt-get install -qqy apt-transport-https
RUN echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
RUN apt-get update -qq
RUN apt-get install -qqy lxc-docker-1.1.1
RUN gpasswd -a peas docker

VOLUME /var/lib/docker
CMD ["/home/peas/repo/contrib/peas-dind/wrapdocker"]
