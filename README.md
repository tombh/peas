[![Build Status](https://travis-ci.org/tombh/peas.svg?branch=master)](https://travis-ci.org/tombh/peas)
Peas
====
__PaaS for the People__

Peas is a Heroku-style Platform as a Service written in Ruby using [Docker](http://www.docker.io). It is heavily
inspired by [Deis](http://deis.io) and [Dokku](https://github.com/progrium/dokku).

Peas' philosophy is to be an accessible and easily hackable PaaS. It doesn't aim to be a complete
enterprise solution. Instead it aims to be a relatively unopinionated, but solid starting place using all the goodness
of Ruby;
[Rspec](http://rspec.info/),
[Bundler](http://bundler.io/),
[Guard](https://github.com/guard/guard),
[Rack](http://rack.github.io/),
[Mongoid](http://mongoid.org/en/mongoid/index.html),
[Docker-api](https://github.com/swipely/docker-api),
[Puma](http://puma.io/),
[Grape](http://intridea.github.io/grape/),
[Sidekiq](http://sidekiq.org/),
[GLI](http://davetron5000.github.io/gli/)
and more.

#Installation
Peas is at a very early stage and has only been tested in development environments. Formal methods
for installing on cloud services such as EC2 and Digital Ocean will come soon. Meanwhile you can try
using the Docker method of installation on cloud servers.

##Local
###Dependencies
You will need
[Docker](https://www.docker.io/gettingstarted/),
[Redis](http://redis.io/) ([OSX installation](http://jasdeep.ca/2012/05/installing-redis-on-mac-os-x/), Linux users can just use your package manager) and
[Mongo DB](http://docs.mongodb.org/manual/installation/). All of these are generally installable via your system's package, no compiling should be necessary.
```bash
docker pull progrium/buildstep # This runs Heroku buildpacks against repos to create deployable app images
git clone https://github.com/tombh/peas.git
bundle install
bundle exec guard
```

##Docker
Note that because Peas itself creates Docker contairers, the Peas Docker images uses a 'Docker in Docker'
setup, this requires the parent container to always be run with the `--privileged` flag.
```
docker pull tombh/peas-dind
docker run --privileged -p 4000:4000 -i peas-dind
```

##Vagrant
There is a Vagrantfile in the root that attempts to get most of the setup done for you:
```bash
vagrant up # Takes a long time first time
vagrant ssh
cd peas
foreman start
```

##CLI client
`gem install peas-cli`

#Usage

Peas aims to follow the conventions and philosophies of Heroku as closely as possible. So it is worth
bearing in mind that a lot of the [Heroku documentation](https://devcenter.heroku.com/) is relevant to Peas.

First thing is to set the domain that points to your Peas installation. If you're developing locally
you can actually just rely on the default `vcap.me` which has wildcard DNS records to point all subdomains
to 127.0.0.1

To use a different domain:
`peas settings --domain customdomain.com`

Next thing is to get into your app's directory. Peas approaches git repos for apps differently from 
other PaaS projects. It does not have a git server so requires app repos to be remotely accessible.
At the moment this is only web accessible repos like on Github and Bitbucket. But the plan is to allow 
pulling from local git paths as well.

Then:
```
peas create
peas deploy
```

You can scale processes using:
`peas scale web=3 worker=2`

These are the only commands currently supported.

#Roadmap
  * Installation for production environments like AWS and Digital Ocean.
  * Users. Peas currently has absolutely no concept of users :/
  * Nodes, or 'pods' if we're keeping with the 'pea' theme. Therefore distributing containers over multiple servers.
  * App config variables. App logs. And so on...