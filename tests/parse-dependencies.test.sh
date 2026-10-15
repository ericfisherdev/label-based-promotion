#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

parse() { printf '%b' "$1" | bash "$SCRIPTS/parse-dependencies.sh" 2>/dev/null | paste -sd, -; }

expect() {
  local actual
  actual="$(parse "$2")"
  if [[ "$actual" == "$3" ]]; then pass "$1"; else fail "$1 (got '$actual', expected '$3')"; fi
}

expect "no line"            "Adds a filter.\n"                          ""
expect "one dependency"     "Adds a filter.\n\nDepends on: #12\n"       "12"
expect "comma list"         "Depends on: #12, #7\n"                     "7,12"
expect "many lines + dupes" "Depends on: #12\ndepends on: #3 #12\n"     "3,12"
expect "indented, CRLF"     "  Depends on: #5\r\n"                      "5"
expect "mid-sentence"       "This PR depends on: #9 maybe\n"            ""
expect "other refs ignored" "Fixes #4\nDepends on: #8\n"                "8"
expect "only leading list"  "Depends on: #12 (see #99)\n"              "12"
expect "URL is ignored"     "Depends on: https://x/pull/7\n"           ""

warning="$(printf 'Depends on: https://x/pull/7\n' | bash "$SCRIPTS/parse-dependencies.sh" 2>&1 >/dev/null)"
if [[ "$warning" == *"::warning::"* ]]; then pass "URL gives a warning"; else fail "URL gives a warning"; fi

expect "words in the list"  "Depends on: #12 and #7\n"                 "12"
warning="$(printf 'Depends on: #12 and #7\n' | bash "$SCRIPTS/parse-dependencies.sh" 2>&1 >/dev/null)"
if [[ "$warning" == *"Only the first list"* ]]; then pass "extra #N gives a warning"; else fail "extra #N gives a warning"; fi
warning="$(printf 'Depends on: #12, #7\n' | bash "$SCRIPTS/parse-dependencies.sh" 2>&1 >/dev/null)"
if [[ -z "$warning" ]]; then pass "clean list gives no warning"; else fail "clean list gives no warning ($warning)"; fi

finish
