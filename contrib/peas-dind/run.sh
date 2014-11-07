#!/bin/bash
# Convenience script for booting the Peas Docker image with a data container.
# Usage: run.sh [api_port] [git_port]
set -e

API_PORT=${1:-4000}
GIT_PORT=${2:-2222}

# Make the assumption that if we're exposing Peas port 80, then this is a non-development environment
if [ "$API_PORT" -eq "80" ]; then
  export DIND_HOST=$(curl icanhazip.com)
else
  PEAS_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../"
  mount_local_repo="-v $PEAS_ROOT:/home/peas/repo"
fi


data_container=$(docker ps -a | grep -P 'busybox:.*peas-data ' | awk '{print $1}')
if [ -z "$data_container" ]; then
	echo "Creating data container..."
  # /var/lib/docker: Internal docker containers (app containers)
  # /data/db: Mongo data
  # /home/peas/.bundler: Gems (just speeds up boot because you don't have to wait for any updated gems to install)
  # /home/git: App repos and SSH public keys
  # TODO: consider having only a single mount and symlinking all the other required persistence paths to it
	docker run \
	  -v /var/lib/docker \
	  -v /data/db \
    -v /home/peas/.bundler \
	  -v /home/git \
	  --name peas-data \
	  busybox true
fi

docker run \
  -it \
  --privileged \
  --rm=true \
  --restart=always \
  --volumes-from peas-data \
  --name=peas \
  -e "PEAS_ENV=$PEAS_ENV" \
  -e "GIT_PORT=$GIT_PORT" \
  $mount_local_repo \
  -p $API_PORT:4000 \
  -p $GIT_PORT:22 \
  -p 9345:9345 \
  tombh/peas
