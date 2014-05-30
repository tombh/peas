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