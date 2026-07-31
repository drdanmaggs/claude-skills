#!/usr/bin/env bash
# sync-labels.sh — bring a repo's label set in line with the canon.
#
# Creates missing canon types and renames labels onto canon names. Renaming via
# the API preserves every issue assignment, which is why consolidation is
# cheap: `refactor` -> `technical-debt` keeps all 37 issues attached.
#
# This script REFUSES TO DELETE, always. Deletion is Mode D of the skill, which
# shows the full list of affected issue numbers and takes approval per bucket.
# A delete here would be a silent one.
#
# Usage:
#   sync-labels.sh create <owner/repo> [--dry-run]        # missing canon types
#   sync-labels.sh rename <owner/repo> <old> <new> [--dry-run]
set -uo pipefail

CANON="$(cd "$(dirname "$0")/.." && pwd)/references/canon.yml"
ACTION="${1:-}"
REPO="${2:-}"

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[ -z "$ACTION" ] && usage
[ -z "$REPO" ] && { echo "sync-labels: owner/repo required" >&2; usage; }
[ -f "$CANON" ] || { echo "sync-labels: canon not found at $CANON" >&2; exit 1; }

case "$*" in *--dry-run*) DRY=1 ;; *) DRY=0 ;; esac
run() {
  if [ "$DRY" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi
}

case "$ACTION" in
  create)
    existing=$(gh label list --repo "$REPO" --limit 200 --json name -q '.[].name') || exit 1
    # types: only — never auto-create areas (they're derived from a repo's own
    # labels) and never auto-create reserved names (other systems own those).
    awk '
      /^[a-z_]+:/ { section = $1; sub(/:$/, "", section) }
      section != "types" { next }
      /^[[:space:]]*- name:/ { name = $3 }
      /^[[:space:]]*color:/  { c = $2; gsub(/"/, "", c) }
      /^[[:space:]]*description:/ {
        d = $0; sub(/^[[:space:]]*description:[[:space:]]*/, "", d)
        if (name != "") { print name "\t" c "\t" d; name = "" }
      }
    ' "$CANON" | while IFS=$'\t' read -r name color desc; do
      if grep -Fxq "$name" <<< "$existing"; then
        printf '  = %s (exists)\n' "$name"
      else
        printf '  + %s\n' "$name"
        run gh label create "$name" --repo "$REPO" --color "$color" --description "$desc"
      fi
    done
    ;;

  rename)
    OLD="${3:-}"; NEW="${4:-}"
    [ -z "$OLD" ] || [ -z "$NEW" ] && { echo "sync-labels: rename needs <old> <new>" >&2; exit 1; }
    n=$(gh issue list --repo "$REPO" --state all --limit 1000 --label "$OLD" --json number -q 'length' 2>/dev/null || echo "?")
    printf '  %s -> %s (%s issues carried across)\n' "$OLD" "$NEW" "$n"
    run gh api --method PATCH "/repos/$REPO/labels/$OLD" -f new_name="$NEW" --silent
    ;;

  delete|remove)
    echo "sync-labels: refusing to delete." >&2
    echo "Deletion runs through Mode D of the issue-labeller skill, which prints" >&2
    echo "every affected issue number and takes approval per bucket first." >&2
    exit 1
    ;;

  *) usage ;;
esac
