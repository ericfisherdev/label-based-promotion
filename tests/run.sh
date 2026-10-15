#!/usr/bin/env bash
# Runs every tests/*.test.sh file. Exits non-zero if any test fails.
set -uo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
status=0
for file in "$dir"/*.test.sh; do
  echo "== $(basename "$file")"
  bash "$file" || status=1
done
exit "$status"
