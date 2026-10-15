#!/usr/bin/env bash
# Usage: mark-promoted.sh <promotion-pr-number> <head-branch> <head-sha>
#
# Runs after a PR merges into qa. Moves the testing PR with the same head
# commit from ready-for-qa to promoted-to-qa. Needs GH_TOKEN and GH_REPO.
set -euo pipefail

promotion_pr="$1"
head="$2"
sha="$3"
script_dir="$(cd "$(dirname "$0")" && pwd)"

testing_pr="$("$script_dir/find-testing-pr.sh" "$head" "$sha")"
if [[ -z "$testing_pr" ]]; then
  echo "::warning::#$promotion_pr merged into qa, but no testing PR has head ${sha:0:7}. Nothing to mark."
  exit 0
fi
original="$(jq -r '.number' <<<"$testing_pr")"

gh pr edit "$original" --add-label promoted-to-qa
for label in ready-for-qa promotion-blocked; do
  if jq -e --arg label "$label" '.labels | index($label)' <<<"$testing_pr" >/dev/null; then
    gh pr edit "$original" --remove-label "$label" \
      || echo "::warning::Could not remove $label from #$original."
  fi
done

gh pr comment "$original" --body "Promoted to qa by #$promotion_pr."
echo "Marked #$original as promoted-to-qa."
