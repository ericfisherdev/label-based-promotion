#!/usr/bin/env bash
# Usage: open-promotion-pr.sh <pr-number> <head-branch> <dependency-report-file>
#
# Opens a draft PR from the same head branch into qa. Does nothing if one is
# already open. Needs GH_TOKEN and GH_REPO.
set -euo pipefail

pr="$1"
head="$2"
deps_report="$3"

existing="$(gh pr list --base qa --head "$head" --state open --json url --jq '.[0].url // empty')"
if [[ -n "$existing" ]]; then
  echo "Promotion PR already open: $existing"
  exit 0
fi

title="$(gh pr view "$pr" --json title --jq '.title')"
body="$(cat <<EOF
Promotes: #$pr

Automated promotion of the tested branch \`$head\` from \`testing\` to \`qa\`.
The \`qa-gate\` check finds the testing PR by head commit, not by this text.

### Dependencies
$(cat "$deps_report")
EOF
)"

url="$(gh pr create --draft --base qa --head "$head" --title "$title" --body "$body")"

gh pr edit "$pr" --remove-label promotion-blocked >/dev/null 2>&1 || true
gh pr comment "$pr" --body "Promotion PR opened: $url"
echo "Opened $url"
