#!/usr/bin/env bash
# Builds a throwaway repo with qa, testing and feature branches, and checks
# that check-branch-clean.sh catches a merge of testing into a feature branch.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mktemp -d)"
trap 'rm -rf "$repo"' EXIT
cd "$repo" || exit 1

git init -q -b qa
git config user.email test@example.com
git config user.name test
git config commit.gpgsign false

commit() { echo "$1" >"$1.txt"; git add "$1.txt"; git commit -qm "$1"; }
# Merge a branch the way a GitHub "Create a merge commit" PR merge does.
pr_merge() { git checkout -q "$1"; git merge -q --no-ff --no-edit "$2"; }
check() { bash "$SCRIPTS/check-branch-clean.sh" qa testing "$1"; }

commit base
git branch testing

# A: a normal ticket branch from qa.
git checkout -q -b feature/A qa
commit a1
commit a2
expect_status 0 "fresh branch from qa is clean" check feature/A

pr_merge testing feature/A
expect_status 0 "branch stays clean after its own merge into testing" check feature/A

# B: another ticket, merged into testing (untested).
git checkout -q -b feature/B qa
commit b1
pr_merge testing feature/B

# C: merges testing into itself. This is the forbidden case.
git checkout -q -b feature/C qa
commit c1
git merge -q --no-edit testing
expect_status 1 "branch that merged testing is blocked" check feature/C

# D: stacked on A (A not promoted yet). A's commits are not from testing.
git checkout -q -b feature/D feature/A
commit d1
expect_status 0 "stacked branch on an unpromoted dependency is clean" check feature/D

# E: a squash merge into testing, then a branch merges testing.
git checkout -q -b feature/E qa
commit e1
git checkout -q testing
git merge -q --squash feature/E >/dev/null 2>&1
git commit -qm "Squash E"
git checkout -q -b feature/F qa
commit f1
git merge -q --no-edit testing
expect_status 1 "merge of testing after a squash merge is blocked" check feature/F

# G: qa moves on (A promoted), and a branch merges qa. That is allowed.
pr_merge qa feature/A
git checkout -q -b feature/G feature/B
git merge -q --no-edit qa
expect_status 0 "merging qa into a branch is allowed" check feature/G

# I: a branch started from testing instead of qa.
git checkout -q -b feature/I testing
commit i1
expect_status 1 "branch started from testing is blocked" check feature/I

# J: a rebase merge of the branch's own work into testing.
git checkout -q -b feature/J qa
commit j1
git checkout -q testing
git cherry-pick feature/J >/dev/null
expect_status 0 "branch stays clean after a rebase merge of its own work" check feature/J

# K: a qa -> testing sync merge, then a fresh branch from qa.
git checkout -q testing
git merge -q --no-ff --no-edit qa
git checkout -q -b feature/K qa
commit k1
expect_status 0 "fresh branch after a qa -> testing sync is clean" check feature/K

# R: a resolve/* branch from testing fixes a conflict for feature/B.
guardrail() { QA_REF=qa TESTING_REF=testing bash "$SCRIPTS/guardrail.sh" "$1" "$2" "$2"; }
git checkout -q -b resolve/B testing
commit r1
expect_status 0 "resolve/* branch into testing is exempt" guardrail testing resolve/B
expect_status 1 "resolve/* branch into qa is not exempt" guardrail qa resolve/B
expect_status 1 "other branch from testing is not exempt" guardrail testing feature/I

# H: testing is reset to qa (sprint reset). Old branches stay valid.
git branch -f testing qa
expect_status 0 "branch is clean after testing reset" check feature/B

# Conflict check against qa.
mergeable() { bash "$SCRIPTS/check-mergeable.sh" qa "$1"; }
git checkout -q -b feature/L qa
echo "L version" >base.txt; git commit -qam "L edits base"
expect_status 0 "branch without conflicts with qa passes" mergeable feature/L
git checkout -q -b feature/M qa
echo "M version" >base.txt; git commit -qam "M edits base"
git checkout -q qa
git merge -q --no-ff --no-edit feature/M
expect_status 1 "branch that conflicts with qa is blocked" mergeable feature/L
expect_status 2 "unknown ref is an error, not a conflict" mergeable no-such-branch

finish
