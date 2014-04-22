###To be released
**Features**:
  * `Dockerfile` to allow ease of installation in multiple environments

**Bugfixes**:
  * Travis now runs both API and CLI specs during the same commit hook

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