#!/usr/bin/env bash
# Shows why PRs into testing and qa must use merge commits only.
#
# feat1 changes a line and goes into testing (merge or squash), then to qa
# (always a merge commit, as the promotion PR does).
#   stacked: feat2 starts from feat1 and changes the same line again.
#   later:   feat3 starts from qa after feat1 is promoted, and changes the
#            same line again.
# With merge commits, both go into testing cleanly. With squash, both
# conflict, because testing has a copy of feat1 that git cannot match to the
# feat1 inside feat2 / feat3.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

# scenario <merge|squash> <stacked|later>: prints "clean" or "conflict".
scenario() {
  local mode="$1" case="$2" repo
  repo="$(mktemp -d)"
  (
    cd "$repo" || exit 1
    git init -q -b qa
    git config user.email test@example.com
    git config user.name test
    git config commit.gpgsign false
    printf 'a\nb\nc\n' >f
    git add f
    git commit -qm base
    git branch testing

    # into_testing <branch>: exit 0 when clean.
    into_testing() {
      git checkout -q testing
      if [[ "$mode" == squash ]]; then
        git merge -q --squash "$1" >/dev/null 2>&1 && git commit -qm "squash $1" >/dev/null 2>&1
      else
        git merge -q --no-ff --no-edit "$1" >/dev/null 2>&1
      fi
    }
    edit() { git checkout -q -b "$1" "$2"; sed -i "s/^b.*$/b-$1/" f; git commit -qam "$1"; }

    edit feat1 qa
    into_testing feat1 || { echo "setup failed: feat1 into testing"; exit; }
    git checkout -q qa
    git merge -q --no-ff --no-edit feat1 || { echo "setup failed: feat1 into qa"; exit; }

    if [[ "$case" == stacked ]]; then
      edit feat2 feat1
      into_testing feat2 && echo clean || echo conflict
    else
      edit feat3 qa
      into_testing feat3 && echo clean || echo conflict
    fi
  )
  rm -rf "$repo"
}

expect() {
  local actual
  actual="$(scenario "$1" "$2")"
  if [[ "$actual" == "$3" ]]; then pass "$4"; else fail "$4 (got '$actual', expected '$3')"; fi
}

expect merge  stacked clean    "merge commits: stacked branch merges cleanly into testing"
expect merge  later   clean    "merge commits: later branch from qa merges cleanly into testing"
expect squash stacked conflict "squash: stacked branch conflicts in testing"
expect squash later   conflict "squash: later branch from qa conflicts in testing"

finish
