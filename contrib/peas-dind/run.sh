#!/bin/bash
set -e

PEAS_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../"

data_container=$(docker ps -a | grep -P 'busybox:latest.*peas-data ' | awk '{print $1}')
if [ -z "$data_container" ]; then
	echo "Creating data container..."
	docker run -v /var/lib/docker -v /data/db --name peas-data busybox true
fi

docker run -it --privileged --volumes-from peas-data -v $PEAS_ROOT:/home/peas -p 4000:4000 tombh/peas
