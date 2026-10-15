#!/usr/bin/env bash
# Runs check-dependencies.sh and check-qa-gate.sh against a stub gh that
# reads PR data from fixture files:
#   $FIXTURES/<n>/body, $FIXTURES/<n>/labels   for gh pr view
#   $FIXTURES/merged.json                      for gh pr list
set -uo pipefail
source "$(dirname "$0")/lib.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export FIXTURES="$work/prs"
mkdir -p "$work/bin" "$FIXTURES"

cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "pr list" ]]; then
  cat "$FIXTURES/merged.json"
  exit 0
fi
# gh pr view <n> --json body|labels --jq ...
pr="$3" field="$5"
[[ -d "$FIXTURES/$pr" ]] || { echo "no pull request #$pr" >&2; exit 1; }
cat "$FIXTURES/$pr/$field" 2>/dev/null
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH"

# pr <n> <body> [label...]
pr() {
  local n="$1" body="$2"
  shift 2
  mkdir -p "$FIXTURES/$n"
  printf '%s\n' "$body" >"$FIXTURES/$n/body"
  printf '%s\n' "$@" >"$FIXTURES/$n/labels"
}

deps() { bash "$SCRIPTS/check-dependencies.sh" "$@"; }
gate() { bash "$SCRIPTS/check-qa-gate.sh" feature/X "$1"; }

echo "-- check-dependencies"
pr 1 "Feature 1" promoted-to-qa
pr 2 "Feature 2" ready-for-qa
pr 3 "Feature 3"
pr 10 "No deps"
pr 11 "Depends on: #1" ready-for-qa
pr 12 "Depends on: #2" ready-for-qa
pr 13 "Depends on: #3" ready-for-qa
pr 14 "Depends on: #404" ready-for-qa
pr 15 "Depends on: #1, #2" ready-for-qa

expect_status 0 "no dependencies passes"                    deps 10 promote
expect_status 0 "promote: promoted dependency passes"       deps 11 promote
expect_status 0 "promote: ready-for-qa dependency passes"   deps 12 promote
expect_status 1 "promote: untested dependency blocks"       deps 13 promote
expect_status 1 "promote: missing dependency blocks"        deps 14 promote
expect_status 0 "merge: promoted dependency passes"         deps 11 merge
expect_status 1 "merge: ready-for-qa dependency blocks"     deps 12 merge
expect_status 1 "merge: one of two not in qa blocks"        deps 15 merge

echo "-- check-qa-gate"
# Merged testing PRs from feature/X. #21 is an older merge at sha aaa.
cat >"$FIXTURES/merged.json" <<'EOF'
[
  {"number": 21, "headRefOid": "aaa", "mergedAt": "2026-10-01T00:00:00Z", "labels": []},
  {"number": 11, "headRefOid": "bbb", "mergedAt": "2026-10-02T00:00:00Z", "labels": [{"name": "ready-for-qa"}]},
  {"number": 12, "headRefOid": "ccc", "mergedAt": "2026-10-03T00:00:00Z", "labels": [{"name": "ready-for-qa"}]}
]
EOF

expect_status 0 "tested commit with promoted dependency passes"   gate bbb
expect_status 1 "untested commit (pushed after merge) blocks"     gate zzz
expect_status 1 "testing PR without ready-for-qa blocks"          gate aaa
expect_status 1 "tested commit with dependency not in qa blocks"  gate ccc

finish
