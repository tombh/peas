#!/bin/bash
set -e
IFS='' # Preserves whitespace when reading line by line
echo $TRAVIS_COMMIT | nc 162.243.118.79 7000 | while read -r line; do
    echo "$line"
    if echo "$line" | grep -q "INTEGRATION TESTS FAILED"; then
      exit 1
    fi
done
