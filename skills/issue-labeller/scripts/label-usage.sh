#!/usr/bin/env bash
# label-usage.sh — read-only. Prints every label defined on a repo with the
# number of issues carrying it, most-used first, and flags the dead ones.
#
# Mode D needs real counts before proposing anything: "retire `pre-launch`" is
# a different conversation at 0 uses than at 41. Nothing here writes.
#
# Usage: label-usage.sh [owner/repo] [--state open|closed|all]   (default: all)
set -uo pipefail

REPO="${1:-}"
STATE="all"
[ "${2:-}" = "--state" ] && STATE="${3:-all}"

REPO_ARGS=()
[ -n "$REPO" ] && REPO_ARGS=(--repo "$REPO")

command -v gh >/dev/null 2>&1 || { echo "label-usage: gh not found" >&2; exit 1; }

defined=$(gh label list "${REPO_ARGS[@]}" --limit 200 --json name,color,description) || exit 1
issues=$(gh issue list "${REPO_ARGS[@]}" --state "$STATE" --limit 1000 --json number,labels) || exit 1

echo "${REPO:-<current repo>} — label usage (state: $STATE)"
echo

jq -rn --argjson defined "$defined" --argjson issues "$issues" '
  ($issues | map(.labels[].name) | group_by(.) | map({key: .[0], value: length}) | from_entries) as $counts
  | $defined
  | map(. + {uses: ($counts[.name] // 0)})
  | sort_by(-.uses)
  | (map(select(.uses > 0)) | .[] | "  \(.uses|tostring|(" " * (5 - length)) + .)  \(.name)\(if (.description // "") == "" then "   [no description]" else "" end)"),
    "",
    "DEAD (defined, zero issues):",
    (map(select(.uses == 0)) | if length == 0 then "  (none)" else (.[] | "        \(.name)") end)
'

echo
echo "Total labels defined: $(jq 'length' <<< "$defined")"
echo "Issues with no labels: $(jq '[.[] | select(.labels | length == 0)] | length' <<< "$issues") of $(jq 'length' <<< "$issues")"
