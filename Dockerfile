# Inspired by @jpetazzo's Docker in Docker: https://github.com/jpetazzo/dind

FROM ubuntu:raring
MAINTAINER tom@tombh.co.uk

# General Peas deps
RUN apt-get install -qqy software-properties-common
RUN apt-add-repository ppa:brightbox/ruby-ng -y
RUN apt-get update
RUN apt-get install -qqy ruby2.1 ruby2.1-dev build-essential libssl-dev git redis-server

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
RUN mkdir /root/.ssh -p && echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config
ADD ./ /home/peas
RUN gem install bundler
RUN cd /home/peas && bundle install

# DinD magic
RUN apt-get install -qqy iptables ca-certificates lxc aufs-tools
ADD https://get.docker.io/builds/Linux/x86_64/docker-0.9.0 /usr/local/bin/docker
RUN chmod +x /usr/local/bin/docker
VOLUME /var/lib/docker
CMD /home/peas/contrib/peas-dind/wrapdocker
