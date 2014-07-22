#!/bin/bash
# Convenience script for booting the Peas Dockerfile with a data container.
# Usage: run.sh [port]
set -e

PORT=${1:-4000}
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
  -v $PEAS_ROOT:/home/peas/repo \
  -p $PORT:4000 \
  -p 9345:9345 \
  tombh/peas
