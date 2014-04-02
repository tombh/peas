#!/bin/bash
set -e
NAME="$1"
REPO="$2"

# Place the app inside the container
ID=$(tar cC /tmp/$REPO . | docker run -i -a stdin progrium/buildstep /bin/bash -c "mkdir -p /app && tar -xC /app")
test $(docker wait $ID) -eq 0
docker commit $ID $NAME > /dev/null

# Run the buildpack process
ID=$(docker run -d $NAME /build/builder)
docker attach $ID
test $(docker wait $ID) -eq 0
docker commit $ID $NAME > /dev/null