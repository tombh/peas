#!/bin/bash
set -e

IFS='' # Preserves whitespace when reading line by line

# 1. CLI CLIENT TESTS. Use all ruby versions from matrix
cd cli
export BUNDLE_GEMFILE=$PWD/Gemfile
bundle exec rspec

# Choose just one Ruby version to trigger the main tests on ci.peas.io
if [ "$TRAVIS_RUBY_VERSION" == "2.1.1" ]; then

  # 3. INTEGRATION TESTS run on a Digital Ocean instance via a simple netcat server.
  # Note the blocking ruby STDIN.gets to prevent prematurely sending EOF to the CI-server.
  if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
    COMMIT_REF=$TRAVIS_COMMIT
  else
    COMMIT_REF="pullrequest$TRAVIS_PULL_REQUEST"
  fi
  rm -f /tmp/ci
  mkfifo /tmp/ci
  cat /tmp/ci | # STDOUT of fifo triggers the `STDIN.gets' in ruby and closes the netcat connection
  ruby -e "p '$COMMIT_REF'; STDIN.gets" | # Keep ruby running and thus netcat conn too
  nc ci.peas.io 7000 | # Connect to the CI server
  while read -r line; do # Read response from server line by line
    # Rspec should always have the string 'Finished in ...' when completed
    if echo "$line" | grep -q "Finished in"; then
      INTEGRATION_TESTS_COMPLETE="1"
    fi
    if echo "$line" | grep -q ", 0 failures"; then
      INTEGRATION_TESTS_SUCCESS="1"
    fi
    if echo "$line" | grep -q "Failed examples"; then
      INTEGRATION_TESTS_SUCCESS="0"
    fi
    # The CI server traps exit and always sends the following signal
    if echo "$line" | grep -q "EXIT FROM CI-SERVER"; then
      # Close the connection to the netcat server
      echo "STAHP SENDIN!" > /tmp/ci
      if [ -z "$INTEGRATION_TESTS_COMPLETE" ]; then
        echo "Integration tests failed to complete"
        exit 1
      else
        [ "$INTEGRATION_TESTS_SUCCESS" == "1" ] && exit 0
        [ "$INTEGRATION_TESTS_SUCCESS" == "0" ] && exit 1
      fi
    fi
    echo "$line" # Output progress as it happens
  done

fi
