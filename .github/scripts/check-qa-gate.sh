#!/usr/bin/env bash
# Usage: check-qa-gate.sh <head-branch> <head-sha>
#
# Required check on every PR into qa. Passes only when:
#   1. A PR from the same branch, with this exact head commit, is merged
#      into testing. (Commits pushed after that merge are untested.)
#   2. That testing PR has ready-for-qa or promoted-to-qa.
#   3. Every "Depends on:" PR of that testing PR is already in qa.
#
# Prints a markdown report on stdout. Needs GH_TOKEN and GH_REPO.
set -euo pipefail

head="$1"
sha="$2"
script_dir="$(cd "$(dirname "$0")" && pwd)"

testing_pr="$("$script_dir/find-testing-pr.sh" "$head" "$sha")"
if [[ -z "$testing_pr" ]]; then
  echo "**No merged PR into \`testing\` has head commit \`${sha:0:7}\`.**"
  echo
  echo "Every commit must pass \`testing\` before \`qa\`. If you pushed after the"
  echo "\`testing\` PR merged, open a new PR from \`$head\` into \`testing\`."
  exit 1
fi

number="$(jq -r '.number' <<<"$testing_pr")"
if ! jq -e '.labels | index("ready-for-qa") or index("promoted-to-qa")' <<<"$testing_pr" >/dev/null; then
  echo "**Testing PR #$number does not have \`ready-for-qa\`.** Add it when testing passes."
  exit 1
fi

echo "Tested in \`testing\` by #$number."
echo
echo "Dependencies:"
"$script_dir/check-dependencies.sh" "$number" merge
