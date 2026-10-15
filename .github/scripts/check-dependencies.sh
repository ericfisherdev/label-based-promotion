#!/usr/bin/env bash
# Usage: check-dependencies.sh <pr-number> <promote|merge>
#
# Reads the "Depends on:" lines of <pr-number> and checks the label of each
# dependency PR.
#
#   mode    promoted-to-qa  ready-for-qa                 other
#   promote pass            pass (merge dependency 1st)  fail
#   merge   pass            fail                         fail
#
# "promote" runs when ready-for-qa is added (the promotion PR may open).
# "merge" runs on the promotion PR into qa (the dependency must be in qa).
#
# Prints a markdown report on stdout. Needs GH_TOKEN and GH_REPO.
set -euo pipefail

pr="$1"
mode="$2"
script_dir="$(cd "$(dirname "$0")" && pwd)"

body="$(gh pr view "$pr" --json body --jq '.body')"
mapfile -t deps < <(printf '%s\n' "$body" | "$script_dir/parse-dependencies.sh")

if [[ ${#deps[@]} -eq 0 ]]; then
  echo "No dependencies."
  exit 0
fi

failed=0
for dep in "${deps[@]}"; do
  [[ "$dep" == "$pr" ]] && continue

  if ! labels="$(gh pr view "$dep" --json labels --jq '.labels[].name' 2>&1)"; then
    echo "- #$dep: could not read the PR: $labels"
    failed=1
  elif grep -qx 'promoted-to-qa' <<<"$labels"; then
    echo "- #$dep: in qa (\`promoted-to-qa\`)."
  elif grep -qx 'ready-for-qa' <<<"$labels"; then
    if [[ "$mode" == "promote" ]]; then
      echo "- #$dep: \`ready-for-qa\`. Merge the promotion PR of #$dep into qa first."
    else
      echo "- #$dep: not in qa yet. Merge the promotion PR of #$dep first."
      failed=1
    fi
  else
    echo "- #$dep: not tested. It needs \`ready-for-qa\` or \`promoted-to-qa\`."
    failed=1
  fi
done

exit "$failed"
