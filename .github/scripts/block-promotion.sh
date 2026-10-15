#!/usr/bin/env bash
# Usage: block-promotion.sh <pr-number> <report-file>...
#
# Adds promotion-blocked to the PR and comments with the reason. Needs
# GH_TOKEN and GH_REPO.
set -euo pipefail

pr="$1"
shift

reason=""
for file in "$@"; do
  [[ -s "$file" ]] && reason+="$(cat "$file")"$'\n\n'
done
[[ -z "$reason" ]] && reason="The promotion workflow failed. See the workflow run log."

gh pr edit "$pr" --add-label promotion-blocked
gh pr comment "$pr" --body "$(cat <<EOF
### Promotion to qa blocked

$reason
Fix the cause, then remove and add \`ready-for-qa\` again to retry.

Run: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID
EOF
)"
