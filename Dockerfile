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
RUN apt-get install mongodb-10gen
# Create the MongoDB data directory
RUN mkdir -p /data/db

# Peas-specific deps
RUN mkdir /root/.ssh -p && /bin/bash -c 'echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config'
ADD ./ /home/peas/repo
RUN gem install bundler

# DinD magic
RUN apt-get install -qqy iptables ca-certificates lxc
RUN apt-get install -qqy apt-transport-https
RUN echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
RUN apt-get update -qq
RUN apt-get install -qqy lxc-docker-1.1.1

VOLUME /var/lib/docker
CMD ["/home/peas/repo/contrib/peas-dind/wrapdocker"]
