#!/usr/bin/env bash
# Usage: scripts/setup-repo.sh [owner/repo]
#
# One-time setup of the testing + qa promotion model on a GitHub repo:
#   1. Creates (or updates) the promotion labels.
#   2. Creates the testing and qa branches from the default branch.
#   3. Lets GitHub Actions open PRs, and keeps head branches after merge.
#   4. Adds branch protection with the guardrail checks as required checks.
#
# Safe to run again. Needs gh with admin rights on the repo.
set -euo pipefail

repo="${1:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner')}"
default_branch="$(gh repo view "$repo" --json defaultBranchRef --jq '.defaultBranchRef.name')"

echo "== Labels"
while IFS='|' read -r name color description; do
  gh label create "$name" --repo "$repo" --color "$color" --description "$description" --force
done <<'EOF'
depends-on-pr|FBCA04|This PR needs another PR. The body has a "Depends on: #N" line.
is-dependency|C5DEF5|Another PR needs this PR. Added by automation.
ready-for-qa|0E8A16|Testing passed. Promote this PR to qa.
promoted-to-qa|5319E7|The change is in qa. Added by automation only.
promotion-blocked|B60205|Automation could not promote. See the PR comment for the reason.
EOF

echo "== Branches"
# create_branch <branch> <from>
create_branch() {
  if gh api "repos/$repo/git/ref/heads/$1" >/dev/null 2>&1; then
    echo "$1 exists"
    return
  fi
  local sha
  sha="$(gh api "repos/$repo/git/ref/heads/$2" --jq '.object.sha')"
  gh api "repos/$repo/git/refs" -f ref="refs/heads/$1" -f sha="$sha" >/dev/null
  echo "$1 created from $2"
}
create_branch qa "$default_branch"
# testing starts from qa. Commits in testing that are not in qa count as
# "from testing" for the guardrail.
create_branch testing qa

echo "== Repo settings"
# The promotion PR must be able to use the same head branch after PR 1 merges.
gh api -X PATCH "repos/$repo" -F delete_branch_on_merge=false >/dev/null
# Lets the workflow GITHUB_TOKEN open the promotion PR.
gh api -X PUT "repos/$repo/actions/permissions/workflow" \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true >/dev/null
echo "delete_branch_on_merge=false, Actions may create PRs"

echo "== Branch protection"
# protect <branch> <allow-force-pushes> <required-check>...
protect() {
  local branch="$1" force="$2"
  shift 2
  local checks
  checks="$(printf '%s\n' "$@" | jq -R . | jq -s 'map({context: .})')"
  jq -n --argjson checks "$checks" --argjson force "$force" '{
    required_status_checks: {strict: false, checks: $checks},
    enforce_admins: false,
    required_pull_request_reviews: {required_approving_review_count: 0},
    restrictions: null,
    allow_force_pushes: $force,
    allow_deletions: false
  }' | gh api -X PUT "repos/$repo/branches/$branch/protection" --input - >/dev/null
  echo "$branch: PR required; checks required: $*; force push allowed: $force"
}
# testing allows force push for the sprint reset (git push --force-with-lease).
protect testing true no-testing-merge app
protect qa false no-testing-merge qa-gate app
