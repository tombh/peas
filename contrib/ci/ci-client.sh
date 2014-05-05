#!/bin/bash
set -e

IFS='' # Preserves whitespace when reading line by line

# 1. CLI CLIENT TESTS. Use all ruby versions from matrix
cd cli
export BUNDLE_GEMFILE=$PWD/Gemfile
bundle exec rspec

# Only use highest ruby version from matrix for all other tests
if [ "$TRAVIS_RUBY_VERSION" == "2.1.1" ]; then

  # 2. PEAS SERVER TESTS but exclude integration tests
  cd ..
  export BUNDLE_GEMFILE=$PWD/Gemfile
  bundle exec rspec --tag ~integration

  # 3. INTEGRATION TESTS run on a Digital Ocean instance via a simple netcat server.
  # Note the blocking ruby STDIN.gets to prevent prematurely sending EOF to the CI-server.
  rm -f /tmp/ci
  mkfifo /tmp/ci
  cat /tmp/ci | # STDOUT of fifo triggers the `STDIN.gets' in ruby and closes the netcat connection
  ruby -e "p ENV['TRAVIS_COMMIT']; STDIN.gets" | # Keep ruby running and thus netcat conn too
  nc ci.peas.io 7000 | # Connect to the CI server
  while read -r line; do # Read response from server line by line
    # Rspec should always have the string 'Finished in ...' when completed
    if echo "$line" | grep -q "Finished in"; then
      INTEGRATION_TESTS_COMPLETE=1
    fi
    # The CI server traps exit and always sends the following signal
    if echo "$line" | grep -q "EXIT FROM CI-SERVER"; then
      # Close the connection to the netcat server
      echo "STAHP SENDIN!" > /tmp/ci
      if [ -z "$INTEGRATION_TESTS_COMPLETE" ]; then
        echo "Integration tests failed to complete"
        exit 1
      else
        exit 0
      fi
    fi
    echo "$line" # Output progress as it happens
  done

fi
