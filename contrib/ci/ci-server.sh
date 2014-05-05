#!/bin/bash
set -e
exec 2>&1 # Redirect STDERR and STDOUT to STDOUT

function finish {
  echo "EXIT FROM CI-SERVER"
}
trap finish EXIT

# Don't forget to setup the Peas repo with:
# git config --add remote.origin.fetch '+refs/pull/*/head:refs/pull/origin/*'
# It brings down pull requests.
# And install tombh/peas, bundler, mongodb and redis-server too.
# And give the ci user the docker group: `gpasswd -a ci docker`

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )/ci-server.sh
PEAS_ROOT="$(dirname $SCRIPTPATH)/../.."

# Because the integration spec_helper bind mounts the live code onto the container we need to make
# sure that no gems are mounted in the process, like through vendor/bundle. So we install gems
# outside the project' path.
export GEM_HOME="$HOME"/.gem

# Handle an incoming request from Travis to run the integration tests
if [ "$1" == "--run-tests" ]; then
  echo "Request to run integration tests accepted..."
  count=0
  while docker ps | grep -q peas-test; do
    [ $count == 0 ] && echo "Waiting for existing integration test to finish..."
    sleep 1
    count=$(($count + 1))
    if [ $count -gt 900 ]; then
      echo "Waited more than 15 mins, aborting..."
      exit 1
    fi
  done
  read -r sha # read the first line to STDIN
  cleaned_ref=$(echo "$sha" | sed -r 's/[^[:alnum:]]//g') # sanitise for security
  if [ -z "$cleaned_ref" ]; then
    echo "No commit to test"
    exit 1
  fi
  cd $PEAS_ROOT
  # Checkout the commit triggered by Travis CI
  git fetch -a
  if echo $cleaned_ref | grep -q "pullrequest"; then
    # Need to do the special Github trick to checkout PRs
    pr_num=${cleaned_ref#pullrequest} # Strip 'pullrequest' from beginning of string
    echo "Checkout Pull Request $pr_num..."
    git checkout "pull/origin/$pr_num"
  else
    # If there's no Pull Request just checkout the SHA hash
    echo "Checking out $cleaned_ref ..."
    git checkout $cleaned_ref
  fi
  # Rebuild the Dockerfile in case the commit includes any unbuilt changes to the Dockerfile
  echo "Rebuilding Dockerfile..."
  docker build -t tombh/peas .
  # Install dependencies for the CLI client
  cd $PEAS_ROOT/cli
  echo "Installing CLI dependencies..."
  bundle install
  # Run the tests
  cd $PEAS_ROOT
  echo "Installing API dependencies"
  bundle install
  echo "Running integration tests"
  bundle exec rspec spec/integration

# Run the CI server
elif [ "$1" == "--server" ]; then
  # Yes, the ncat server and the code it runs for each connection is all here in the same file -
  # just keeps things simple and together in one place.
  echo "Starting Ncat CI server..."
  ncat -vvv --listen --keep-open --max-conns 6 --source-port 7000 --sh-exec "$SCRIPTPATH --run-tests"
fi
