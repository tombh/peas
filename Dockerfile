# Inspired by @jpetazzo's Docker in Docker: https://github.com/jpetazzo/dind

FROM ubuntu:14.10
MAINTAINER tom@tombh.co.uk

RUN apt-get update
RUN apt-get install -qqy ruby ruby-dev rubygems mongodb build-essential libssl-dev libpq-dev

# Create a Git server
RUN apt-get install -qqy openssh-server
RUN useradd -d /home/git git
RUN echo "peas ALL=(git) NOPASSWD: ALL" >> /etc/sudoers # Allow peas to sudo into the git user

# DinD magic
RUN apt-get install -qqy iptables ca-certificates lxc
RUN apt-get install -qqy apt-transport-https
RUN echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
RUN apt-get update -qq
RUN apt-get install -qqy lxc-docker-1.3.0

# Peas-specific deps
RUN useradd -d /home/peas peas
RUN chsh -s /bin/bash peas
ADD ./ /home/peas/repo
RUN echo "export GEM_HOME=/home/peas/.bundler" > /home/peas/.profile
RUN echo "export PATH=$PATH:/home/peas/.bundler/bin" >> /home/peas/.profile
RUN chown -R peas /home/peas
RUN mkdir /var/log/peas
RUN chown peas:peas /var/log/peas
RUN gpasswd -a peas docker

VOLUME /var/lib/docker
CMD ["/home/peas/repo/contrib/peas-dind/wrapdocker"]
