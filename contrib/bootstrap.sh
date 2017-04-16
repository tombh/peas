#!/bin/bash
set -e

# Install `pacapt', a wrapper around popular *nix package managers
# See; https://github.com/icy/pacapt
wget -O /usr/local/bin/pacapt https://github.com/icy/pacapt/raw/ng/pacapt
chmod 755 /usr/local/bin/pacapt

# Upgrade the package database
pacapt -Sy

# Check OS
if [[ "$(uname)" == "Darwin" ]]; then
	# Use boot2docker for OS X
	docker='boot2docker'
else
	# Try to isolate the Docker package, avoiding packages that aren't to do with Linux containers
	docker=$(pacapt -Ss docker | grep -i container | head -1 | awk '{print $1;}')
fi

# Install Docker. Crudely bombard the installation with 'y' in case there are any user prompts
printf 'y\ny\ny\ny\ny\n' | pacapt -S $docker

# Setup and run the Peas DinD container to run the API on port 80 and Git server on port 22
curl -sSL https://raw.githubusercontent.com/tombh/peas/master/contrib/peas-dind/run.sh | sh -s 80 22
