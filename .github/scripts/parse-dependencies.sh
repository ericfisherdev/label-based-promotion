#!/usr/bin/env bash
# Reads a PR body on stdin and prints each PR number named on a
# "Depends on:" line, one per line, sorted and de-duplicated. Only the
# leading list of "#N" after the colon counts:
#
#   Depends on: #4511
#   Depends on: #4511, #4520 (see #99)   -> 4511, 4520, and a warning
#
# Writes a warning on stderr when a "Depends on:" line has no "#N" list (for
# example a URL), or has more "#N" after the list, so a typo does not
# silently pass the gate.
set -euo pipefail
shopt -s nocasematch

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*depends\ on:(.*)$ ]] || continue
  rest="${BASH_REMATCH[1]}"
  list="$(grep -oE '^([[:space:],]*#[0-9]+)+' <<<"$rest" || true)"
  if [[ -z "$list" ]]; then
    echo "::warning::Ignored \"${line}\". Write dependencies as: Depends on: #123, #456" >&2
    continue
  fi
  if [[ "${rest:${#list}}" =~ \#[0-9] ]]; then
    echo "::warning::Only the first list counts in \"${line}\". Write dependencies as: Depends on: #123, #456" >&2
  fi
  grep -oE '[0-9]+' <<<"$list"
done | sort -un
