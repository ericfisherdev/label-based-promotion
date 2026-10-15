#!/usr/bin/env bash
# Usage: guardrail.sh <base-branch> <head-branch> <head-sha>
#
# The no-testing-merge required check. Runs check-branch-clean.sh, except for
# resolve/* branches into testing.
#
# A resolve/* branch starts from testing, merges one feature branch and fixes
# the conflict there, so that the fix lives on testing and never in the
# feature branch. It contains testing commits by design. It can never go to
# qa: no-testing-merge on the qa PR and the clean check in promote-to-qa
# still apply to it.
set -euo pipefail

base="$1"
head="$2"
sha="$3"

if [[ "$base" == "testing" && "$head" == resolve/* ]]; then
  echo "\`$head\` is a conflict-resolution branch into \`testing\`. Check skipped."
  exit 0
fi

"$(dirname "$0")/check-branch-clean.sh" "${QA_REF:-origin/qa}" "${TESTING_REF:-origin/testing}" "$sha"
