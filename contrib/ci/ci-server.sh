#!/bin/bash
set -e

# Don't forget to setup the Peas repo with:
# git config --add remote.origin.fetch '+refs/pull//head:refs/remotes/origin/pr/'
# It brings down pull requests.

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )/ci-server.sh
PEAS_ROOT="$(dirname $SCRIPTPATH)/../.."

# Handle an incoming request from Travis to run the integration tests
if [ "$1" == "--run-tests" ]; then
  read -r sha # read the first line to STDIN
  cleaned_sha=$(echo "$sha" | sed -r 's/[^[:alnum:]]//g') # sanitise for security
  # Checkout the commit triggered by Travis CI
  cd $PEAS_ROOT
  cd /home/ci/repo && git pull && git checkout $cleaned_sha
  # Install dependencies for the CLI client only
  cd $PEAS_ROOT/cli
  bundle install --deployment --without development
  # Run the tests
  cd $PEAS_ROOT
  bundle install --deployment --without development
  bundle exec rspec --tag integration
  # Check if they passed
  if [ $? -ne 0 ]; then
    echo "INTEGRATION TESTS FAILED"
    exit 1
  fi

# Run the CI server
elif [ "$1" == "--server" ]; then
  # Yes, the ncat server and the code it runs for each connection is all here in the same file -
  # just keeps things simple and together in one place.
  echo "Starting Ncat CI server..."
  ncat --listen --keep-open --max-conns 1 --source-port 7000 --sh-exec "$SCRIPTPATH --run-tests"
fi
