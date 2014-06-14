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

#Quickstart
```bash
git clone https://github.com/tombh/peas.git
gem install peas-cli
cd peas
./contrib/peas-dind/run.sh
=> (lots of logs about Peas booting up)
cd [my cool app on github]
peas create
peas deploy
=>
"-----> Installing dependencies
 -----> Discovering process types
 -----> Scaling process 'web:1'
        Deployed to http://mycoolapp.vcap.me:4000"
curl mycoolapp.vcap.me:4000
=> Yay!
```

#Installation
Peas is at a very early stage and has only been tested in development environments. Formal methods
for installing on cloud services such as EC2 and Digital Ocean will come soon. Meanwhile you can try
using the Docker method of installation on cloud servers.

##Local
This is the preferred method for local development, but note that local development is also possible
with the Docker installation method.
You will need;
[Docker](https://www.docker.io/gettingstarted/),
[Redis](http://redis.io/) ([OSX installation](http://jasdeep.ca/2012/05/installing-redis-on-mac-os-x/),
Linux users can just use your package manager) and [Mongo DB](http://docs.mongodb.org/manual/installation/).
All of these are generally installable via your system's package manager, no compiling should be necessary.
```bash
docker pull progrium/buildstep # This runs Heroku buildpacks against repos to create deployable app images
git clone https://github.com/tombh/peas.git
bundle install
bundle exec guard
```

The Peas API will be available at `vcap.me:4000`.

##Docker
This installation method will work anywhere that Docker can be installed, so both locally and on
remote servers like AWS and Digital Ocean (though this hasn't been tested yet, please let us know if
you have success installing Peas on a remote server).

To install and boot just use `./contrib/peas-dind/run.sh`. For a detailed explanation read
`contrib/peas-dind/README.md`.

The Peas API will be available at `vcap.me:4000`.

##Vagrant
Most likely useful to you if you are on Windows. There is a Vagrantfile in the root that attempts to
get most of the setup done for you:
```bash
vagrant up # Takes a long time first time
vagrant ssh
cd peas
foreman start
```

The Peas API will be available at `peas.local:4000`.

##CLI client
To interact with the Peas API you will need to install the command line client:
`gem install peas-cli`

During development you will find it useful to use the `peas-dev` command. It uses the live code in
your local repo as the CLI client. You can put it in your `$PATH` with something like;
`sudo ln -s $(pwd)/peas-dev /usr/local/bin/peas-dev`

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

List of current commands;
```
config   - Add, remove and list config for an app
create   - Create an app
deploy   - Deploy an app
help     - Shows a list of commands or help for one command
logs     - Show logs for an app
scale    - Scale an app
settings - Set Peas global settings
```

#Roadmap
  * Installation for production environments like AWS and Digital Ocean.
  * Users. Peas currently has absolutely no concept of users :/
  * Nodes, or 'pods' if we're keeping with the 'pea' theme. Therefore distributing containers over multiple servers.
