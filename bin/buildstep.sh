#!/bin/bash
set -e
NAME="$1"
REMOTE="$2"

# Clone or update the repo
mkdir -p /tmp/peas/repos
tmp_repo_path=/tmp/peas/repos/$NAME
if [ -d "$tmp_repo_path/.git" ]; then
	cd $tmp_repo_path && git pull $REMOTE
else
	git clone --depth 1 $REMOTE $tmp_repo_path
fi

# Place the app inside the container
ID=$(tar cC $tmp_repo_path . | docker run -i -a stdin progrium/buildstep /bin/bash -c "mkdir -p /app && tar -xC /app")
test $(docker wait $ID) -eq 0
docker commit $ID $NAME > /dev/null

# Run the buildpack process
ID=$(docker run -d $NAME /build/builder)
docker attach $ID
test $(docker wait $ID) -eq 0
docker commit $ID $NAME > /dev/null
