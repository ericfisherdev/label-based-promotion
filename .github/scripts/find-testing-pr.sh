#!/usr/bin/env bash
# Usage: find-testing-pr.sh <head-branch> <head-sha>
#
# Finds the merged PR from <head-branch> into testing whose head was exactly
# <head-sha>, and prints it as JSON: {"number": 12, "labels": ["ready-for-qa"]}.
# Prints nothing when no such PR exists.
#
# The qa gate and mark-promoted use this lookup instead of the "Promotes:"
# line in the PR body, because anyone can edit the body.
# Needs GH_TOKEN and GH_REPO.
set -euo pipefail

head="$1"
sha="$2"

gh pr list --base testing --head "$head" --state merged --limit 50 \
  --json number,headRefOid,labels,mergedAt \
  | jq -c --arg sha "$sha" '
      map(select(.headRefOid == $sha))
      | sort_by(.mergedAt) | last // empty
      | {number, labels: [.labels[].name]}'
