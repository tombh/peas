#!/bin/bash
# Convenience script for booting the Peas Dockerfile with a data container.
# Usage: run.sh [api_port] [git_port]
set -e

API_PORT=${1:-4000}
GIT_PORT=${2:-2222}

# Make the assumption that if we're exposing Peas port 80, then this is a non-development environment
if [ $API_PORT = 80 ]; then
  export DIND_HOST=$(curl icanhazip.com)
fi

PEAS_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../"

data_container=$(docker ps -a | grep -P 'busybox:.*peas-data ' | awk '{print $1}')
if [ -z "$data_container" ]; then
	echo "Creating data container..."
	docker run \
	  -v /var/lib/docker \
	  -v /data/db \
	  -v /var/lib/gems \
	  --name peas-data \
	  busybox true
fi

docker run \
  -it \
  --privileged \
  --rm=true \
  --volumes-from peas-data \
  -e "PEAS_ENV=$PEAS_ENV" \
  -e "GIT_PORT=$GIT_PORT" \
  -v $PEAS_ROOT:/home/peas/repo \
  -p $API_PORT:4000 \
  -p $GIT_PORT:22 \
  -p 9345:9345 \
  tombh/peas
