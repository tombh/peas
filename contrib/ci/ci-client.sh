#!/bin/bash
set -e
IFS='' # Preserves whitespace when reading line by line
TESTS_COMPLETE=0

which nc
which netcat

while read -r line; do
  echo "$line"
  # The CI server echoes out INTEGRATION TESTS FAILED
  if echo "$line" | grep -q "INTEGRATION TESTS FAILED"; then
    exit 1
  fi
  # Rspec should allows have the string 'Finished in ...' when completed
  if echo "$line" | grep -q "Finished in"; then
    TESTS_COMPLETE=1
  fi
done <<< $(echo $TRAVIS_COMMIT | nc ci.peas.io 7000) # Prevents using a subshell which obscures vars

if [ $TESTS_COMPLETE == 0 ]; then
  echo "Integration tests failed to complete"
  exit 1
fi
