#Dockerfile

##Building
Because Peas itself creates Docker containers, running Peas in Docker means runnning Docker
inside Docker. Luckily this is possible using the simple tweaks provided by @jpetazzo's
[DinD scripts](https://github.com/jpetazzo/dind).

However, there is one caveat; The `progrium/buildstep` image cannot be bundled during build time. This is for 2 reasons:
1) the parent Docker container requires '--privileged' permissions to run Docker commands internally, this flag
cannot be set in a Dockerfile. 2) AUF mounts cannot be created inside an existing Docker container, therefore Docker's
`/vare/lib/docker` has to exist as a Docker volume (which basically means that any files in that folder cannot be
committed to new images). Therefore `progrium/buildstep` is installed via `wrapdocker` when `peas-dind` is first run.

To build goto the project root and issue: `docker build -t tombh/peas .`