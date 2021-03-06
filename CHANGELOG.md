###0.7.1
**18th January 2015**    
**Bugfixes**:
* Fix for CLI triggering Stack overflow. Was caused by not updating all methods to older
  non-keyword args.

###0.7.0
**16th January 2015**    
**Features**:
* Users! Authentication using the user's SSH key.
* API and Switchboard are protected by an API key. First user automatically becomes super admin.

###0.6.0
**1st January 2015**    
**Features**:
* SSL for the API and the socket server

###0.5.0
**21st November 2014**    
**Features**:
  * Send DinD Procfile logs to /var/logs/peas/*
**Bugfixes**:
  * Enforce lower case app names, through CLI and API

###0.4.0
**19th November 2014**    
**Features**:
  * `peas admin run` CLI command. Allows one-off commands and interactive sessions to be run on controller
  * Upgraded Docker to 1.3.0
  * Upgraded parent DinD Ubuntu version to 14.10
  * Updated gems

###0.3.2
**5th November 2014**     
**Bugfixes**:
  * `peas run` needed to require io/console to accept STDIN.raw

###0.3.1
**1st November 2014**    
**Features**:
  * `peas run` CLI command. Allows one-off commands and interactive sessions to be run

###0.3.0
**23rd August 2014**    
**Features**:
  * Git server deploys, ie; `git push peas`. No more CLI deploys.
  * API change: apps are ID'd by their name not their first SHA1 (that was always a bad idea)
  * CLI logs command defaults to not following logs, use `--follow` to follow.
  * Main specs are run on ci.peas.io, so only CLI specs are run on Travis now. Travis still triggers and reports all
  tests.

###0.2.1
**1st August 2014**    
**Features**:
  * New methods to list and destroy apps.

###0.2.0
**24th July 2014**    
**Features**:
  * Addons. Currently MongoDB and Postgres. Automatically added to app if admin connection provided.

###0.1.3
**11th July 2014**    
**Features**:
  * Upgrade gems
  * Upgrade Docker-in-Docker version to v1.1.1

###0.1.2
**8th July 2014**    
**Features**:
  * Removal of Redis and Sidekiq.
  * Switchboard-based workers
  * Pubsub commands in Switchboard
  * Upgrade Docker-in-Docker version to v1.0.1

###0.1.1
**14th June 2014**    
**Features**:
  * Introducing Switchboard: a Celluloid-based messaging client/server for internal messaging.
  * App logging in capped MongoDB collections and new `peas logs` command.

**Bugfixes**:
  * App builds stop and return messages on error

###0.1.0
**30th May 2014**    
**Features**:
  * App config for setting app's environment variables. Vars also available during build.
  * Better namespacing of API methods. Eg; App methods live under /app/[sha1]/[method]
  * CLI client checks minor version match for compatibility.

###0.0.4
**5th April 2014**    
**Features**:
  * `Dockerfile` to allow ease of installation in multiple environments
  * Integration tests that use the Dockerfile image for consistently reproducible testing
  * Travis now runs API, CLI and Integration specs during the same commit hook

**Bugfixes**:
  * `/setting` API method changed to `/settings`, now works with CLI (picked up by integration tests)

###0.0.3
**17th April 2014**    
**Bugfixes**:
  * Tolerance of Docker warnings by moving to use of Docker Remote API over shelling to CLI.
  * Default domain uses same port as Puma's default development port.

**Features**:
  * Using docker-api gem to interact with Docker Remote API rather than interact with the docker
  binary via shell calls. This also allows for much deeper testing of interaction with Docker
  because there are no BASH calls to docker. All the various stages of building and running
  containers can be isolated and stubbed.
  * Added more verbose comments to Pea and App models.

###0.0.2
**6th April 2014**    
Initial release.
