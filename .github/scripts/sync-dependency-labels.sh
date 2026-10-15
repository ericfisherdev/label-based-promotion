#!/usr/bin/env bash
# Usage: sync-dependency-labels.sh <pr-number>
#
# Adds depends-on-pr to the PR when its body has a "Depends on:" line, and
# removes it when the line is gone. Adds is-dependency to each dependency.
# Needs GH_TOKEN and GH_REPO.
set -euo pipefail

pr="$1"
script_dir="$(cd "$(dirname "$0")" && pwd)"

body="$(gh pr view "$pr" --json body --jq '.body')"
mapfile -t deps < <(printf '%s\n' "$body" | "$script_dir/parse-dependencies.sh")

if [[ ${#deps[@]} -eq 0 ]]; then
  gh pr edit "$pr" --remove-label depends-on-pr >/dev/null 2>&1 || true
  echo "#$pr has no dependencies."
  exit 0
fi

gh pr edit "$pr" --add-label depends-on-pr
for dep in "${deps[@]}"; do
  [[ "$dep" == "$pr" ]] && continue
  if gh pr edit "$dep" --add-label is-dependency; then
    echo "#$dep labeled is-dependency."
  else
    echo "::warning::#$pr depends on #$dep, but #$dep could not be labeled (not found?)."
  fi
done
