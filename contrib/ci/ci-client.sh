#!/bin/bash
set -e
IFS='' # Preserves whitespace when reading line by line
tests_complete=0
echo $TRAVIS_COMMIT | nc ci.peas.io 7000 | while read -r line; do
    echo "$line"
    if echo "$line" | grep -q "INTEGRATION TESTS FAILED"; then
      exit 1
    fi
    if echo "$line" | grep -q "Finished in"; then
      tests_complete=1
    fi
done

if [ $tests_complete == 0 ]; then
  echo "Integration tests failed to complete"
  exit 1
fi
