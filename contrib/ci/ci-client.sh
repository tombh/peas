#!/bin/bash
set -x
set -e
IFS='' # Preserves whitespace when reading line by line
INTEGRATION_TESTS_COMPLETE=0

# CLI client tests. Use all ruby versions from matrix
cd cli
export BUNDLE_GEMFILE=$PWD/Gemfile
bundle exec rspec

# Only use highest ruby version from matrix for all other tests
if [ "$TRAVIS_RUBY_VERSION" == "2.1.1" ]; then

  # Peas server tests but exclude integration tests
  cd ..
  export BUNDLE_GEMFILE=$PWD/Gemfile
  bundle exec rspec --tag ~integration

  # Integration tests run on a Digital Ocean instance via a simple netcat server
  while read -r line; do
    echo "$line"
    # The CI server echoes out INTEGRATION TESTS FAILED
    if echo "$line" | grep -q "INTEGRATION TESTS FAILED"; then
      exit 1
    fi
    # Rspec should allows have the string 'Finished in ...' when completed
    if echo "$line" | grep -q "Finished in"; then
      INTEGRATION_TESTS_COMPLETE=1
    fi
  done <<< $(ruby -e "p ENV['TRAVIS_COMMIT']" | nc -vvv ci.peas.io 7000) # Prevents using a subshell which obscures vars

  if [ $INTEGRATION_TESTS_COMPLETE == 0 ]; then
    echo "Integration tests failed to complete"
    exit 1
  fi

fi
