# Shared helpers for tests/*.test.sh.

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.github/scripts" && pwd)"
failures=0

pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; failures=$((failures + 1)); }

# expect_status <expected-exit-code> <name> <command...>
expect_status() {
  local expected="$1" name="$2"
  shift 2
  local output status
  output="$("$@" 2>&1)"
  status=$?
  if [[ "$status" -eq "$expected" ]]; then
    pass "$name"
  else
    fail "$name (exit $status, expected $expected)"
    sed 's/^/       /' <<<"$output"
  fi
}

finish() {
  [[ "$failures" -eq 0 ]] || { echo "  $failures failure(s)"; exit 1; }
}
