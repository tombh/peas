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
[GLI](http://davetron5000.github.io/gli/),
[Celluloid](http://celluloid.io/),
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
.
.
.
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

**Local development environment**    
This is the preferred method for local development, but note that local development is also possible
with the Docker installation method.
All you will need is; Ruby 2.1,
[Docker](https://www.docker.io/gettingstarted/)
and [Mongo DB](http://docs.mongodb.org/manual/installation/).
All of these are generally installable via your system's package manager, no compiling should be necessary.
```bash
docker pull progrium/buildstep # This runs Heroku buildpacks against repos to create deployable app images
git clone https://github.com/tombh/peas.git
bundle install
bundle exec guard
```

The Peas API will be available at `vcap.me:4000`.

**Docker**    
This installation method will work anywhere that Docker can be installed, so both locally and on
remote servers like AWS and Digital Ocean.

To install and boot just use `./contrib/peas-dind/run.sh` (ie. you will need to have cloned the repo
first). For a detailed explanation read    
`contrib/peas-dind/README.md`.

The Peas API will be available at `vcap.me:4000`.

**Vagrant**    
Most likely useful to you if you are on Windows. There is a Vagrantfile in the root of the project.
All it does is boot a recent VM of Ubuntu and then installs Peas using the Docker method above.

The Peas API will be available at `peas.local:4000`.

**CLI client**    
To interact with the Peas API you will need to install the command line client:
`gem install peas-cli`

During development you will find it useful to use the `peas-dev` command. It uses the live code in
your local repo as the CLI client. You can put it in your `$PATH` with something like;    
`sudo ln -s $(pwd)/peas-dev /usr/local/bin/peas-dev`

#Usage

**Setup**
Peas aims to follow the conventions and philosophies of Heroku as closely as possible. So it is worth
bearing in mind that a lot of the [Heroku documentation](https://devcenter.heroku.com/) is relevant to Peas.

First thing is to set the domain that points to your Peas installation. If you're developing locally
you can actually just rely on the default `vcap.me` which has wildcard DNS records to point all subdomains
to 127.0.0.1

To use a different domain:
`peas settings --domain customdomain.com`

**Deploying**
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

**Services**
If a service URI is provided to Peas' admin settings then all subsequently created apps will be given an instance of
that service. Therefore, by issuing somehting like;    
`peas admin settings mongodb.uri mongodb://root:password@mongoservice.com`
all new apps will get created with a config variable of something like;    
'MONGDB_URI=mongodb://appname:2f7n87fr@mongoservice.com/appname'

New services can be added by creating a new class in `lib/services`. You can use any of the existing service classes as
a template.

**All current CLI commands**
```
admin  - Admin commands
config - Add, remove and list config for an app
create - Create an app
deploy - Deploy an app
help   - Shows a list of commands or help for one command
logs   - Show logs for an app
scale  - Scale an app
```

#Roadmap
  * Installation for production environments like AWS and Digital Ocean.
  * Users. Peas currently has absolutely no concept of users :/
  * Nodes, or 'pods' if we're keeping with the 'pea' theme. Therefore distributing containers over multiple servers.

##Video Presentation
Given at Bristol Ruby User Group on June 26th 2014 (1h16m)    
<a href="http://www.youtube.com/watch?feature=player_embedded&v=Y5vb5YEatnw
" target="_blank"><img src="http://img.youtube.com/vi/Y5vb5YEatnw/0.jpg"
alt="Peas presentation" width="480" border="10" /></a>
