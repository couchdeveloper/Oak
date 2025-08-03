#!/bin/bash

# Usage: ./repeat-tests.sh [REPEATS]
REPEATS=${1:-100}  # Default to 100 if not provided

start_time=$(date +%s)

for ((i=1; i<=REPEATS; i++)); do
  printf "\rRunning test %d/%d..." "$i" "$REPEATS"
  output=$(swift test 2>&1)
  status=$?
  # Check for exit code or failure pattern in output
  if [ $status -ne 0 ] || echo "$output" | grep -q -E 'failed|issue'; then
    echo "\nTest failed on run $i"
    echo "$output"
    echo "$output" | grep -E 'Executed [0-9]+ tests'
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    echo "Elapsed time: ${elapsed}s"
    exit 1
  fi
  if [ $i -eq $REPEATS ]; then echo; fi
done

end_time=$(date +%s)
elapsed=$((end_time - start_time))
echo "$output" | grep -E 'Executed [0-9]+ tests'
echo "Elapsed time: ${elapsed}s"