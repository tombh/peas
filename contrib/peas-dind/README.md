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

To build go to the project root and issue: `docker build -t tombh/peas .`

##Running
If you just want to run the image and don't care what's going on under the hood then run;
`./run.sh [API port, defaults to 4000]` in this directory. Otherwise read for a detailed description...

There are 2 things to bear in mind when running Peas' Docker image. Firstly, that because Peas
creates Docker containers inside a parent Docker container you must remember to always
provide the `--privileged` flag when running Docker commands. Secondly, in order to persist data,
namely, app containers and the Peas API database, you will need to use
a [Data Volumes](http://docs.docker.io/use/working_with_volumes/). So, let's create that first.
Individual app containers are created by Docker, so their data is kept at `/var/lib/docker` and
MongoDB keeps its data at `/data/db`. Therefore our Data Volume can be created with:    
`docker run -v /var/lib/docker -v /data/db --name peas-data busybox true`    
And then to run the Peas container using that Data Volume:    
`docker run -t --privileged --volumes-from peas-data -p 4000:4000 -i tombh/peas`    
If you would like to hack on the codebase whilst it's running in the container you can mount your
code into the container:    
`docker run -t --privileged --volumes-from peas-data -v [path to peas codebase on your machine]:/home/peas -p 4000:4000 -i tombh/peas`

##Useful commands
Remove all untagged images
`docker rmi $(docker images | grep "^<none>" | tr -s ' ' | cut -d ' ' -f 3)`

Remove all containers that aren't Peas data containers
`docker rm $(docker ps -a | grep -v peas-data | tr -s ' ' | cut -d ' ' -f 1)`
