#!/usr/bin/env bash
# Usage: check-mergeable.sh <qa-ref> <head-ref>
#
# Fails when <head-ref> conflicts with <qa-ref>. Does not change the working
# tree (git merge-tree, git 2.38+). Prints a markdown report on stdout.
set -uo pipefail

qa="$1"
head="$2"

# merge-tree also exits 1 for an unknown ref, so check the refs first.
for ref in "$qa" "$head"; do
  if ! git rev-parse --verify --quiet "$ref^{commit}" >/dev/null; then
    echo "Could not test the merge into \`qa\`: unknown ref \`$ref\`."
    exit 2
  fi
done

output="$(git merge-tree --write-tree --name-only --no-messages "$qa" "$head" 2>&1)"
status=$?

case "$status" in
  0)
    echo "No conflicts with \`qa\`."
    exit 0
    ;;
  1)
    echo "**Branch conflicts with \`qa\`.**"
    echo
    echo "Merge \`qa\` into the branch and fix the conflicts. Merging \`qa\` is allowed;"
    echo "merging \`testing\` is not. Push, open a new PR from this branch into \`testing\`,"
    echo "and add \`ready-for-qa\` to that PR after it is tested."
    echo
    echo '```'
    tail -n +2 <<<"$output"
    echo '```'
    exit 1
    ;;
  *)
    echo "Could not test the merge into \`qa\`: $output"
    exit "$status"
    ;;
esac
