#!/usr/bin/env bash
# Usage: check-branch-clean.sh <qa-ref> <testing-ref> <head-ref>
#
# Fails when <head-ref> contains commits that came from the testing branch.
#
# A commit "came from testing" when it is on the first-parent chain of
# testing and is not in qa. Every PR merge into testing (merge, squash or
# rebase) adds commits to that chain. The commits of a feature branch enter
# testing only as the second parent of a merge commit, so they are never on
# the chain. If a feature branch merges testing, the tip of testing (a chain
# commit) becomes reachable from the branch, and this check catches it.
#
# Prints a markdown report on stdout.
set -euo pipefail

qa="$1"
testing="$2"
head="$3"

mapfile -t leaked < <(comm -12 \
  <(git rev-list --first-parent "$testing" --not "$qa" | sort) \
  <(git rev-list "$head" --not "$qa" | sort))

if [[ ${#leaked[@]} -eq 0 ]]; then
  echo "Branch is clean: no commits from \`testing\` that are not in \`qa\`."
  exit 0
fi

echo "**Branch contains ${#leaked[@]} commit(s) from \`testing\` that are not in \`qa\`.**"
echo
echo "Never merge \`testing\` into a feature branch. Rebuild the branch from \`qa\`"
echo "and cherry-pick only the commits of this ticket."
echo
echo '```'
git log --no-walk --oneline "${leaked[@]:0:20}"
[[ ${#leaked[@]} -gt 20 ]] && echo "... and $(( ${#leaked[@]} - 20 )) more"
echo '```'
exit 1
