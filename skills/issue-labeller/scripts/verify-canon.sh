#!/usr/bin/env bash
# verify-canon.sh — CI guard. Fails if any skill or agent hard-codes a GitHub
# label that isn't in the canon.
#
# This is what stops the callers drifting back. Before it existed, five skills
# wrote `Labels: testing, auto-generated, needs-manual-work` into issue BODIES;
# none of those three labels has ever existed in any repo, and one of them
# (`flaky-test`) was being queried by test-fixer against a label nothing set.
#
# Accepts:  canon types, canon reserved names, and any well-formed area: label
#           (areas are declared per repo, so the canon can't enumerate them).
# Rejects:  everything else, with a pointed message for priority-shaped names.
#
# Run: skills/issue-labeller/scripts/verify-canon.sh [root]
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/../../.." && pwd)}"
CANON="$ROOT/skills/issue-labeller/references/canon.yml"

[ -f "$CANON" ] || { echo "verify-canon: canon not found at $CANON" >&2; exit 1; }

# Section-aware extraction. `known_instances` deliberately lists retired
# priority labels, and `forbidden_patterns` looks like a list of names, so a
# naive grep over the whole file would allow exactly what we're banning.
allowed=$(awk '
  /^[a-z_]+:/ { section = $1; sub(/:$/, "", section) }
  section == "types"         && /^[[:space:]]*- name:/ { print $3 }
  section == "area_baseline" && /name:/ {
    if (match($0, /name: "[^"]+"/)) { s = substr($0, RSTART + 7, RLENGTH - 8); print s }
  }
  section == "reserved" && /^[[:space:]]*- / {
    v = $0; sub(/^[[:space:]]*- /, "", v); gsub(/"/, "", v); print v
  }
' "$CANON" | sort -u)

[ -n "$allowed" ] || { echo "verify-canon: parsed no labels out of $CANON" >&2; exit 1; }

is_allowed() {
  case "$1" in
    area:*)
      # Areas are repo-declared; the canon can only police their shape.
      [[ "$1" =~ ^area:[a-z0-9]+(-[a-z0-9]+)*$ ]] && return 0
      return 1 ;;
  esac
  grep -Fxq -- "$1" <<< "$allowed"
}

fail=0
report() { # <file> <line> <label> <hint>
  fail=$((fail + 1))
  printf '  %s:%s  unknown label %s\n      %s\n' "$1" "$2" "$3" "$4"
}

hint_for() {
  case "$1" in
    priority*|Priority*|*-priority|critical|high|medium|low|p[0-4])
      echo "the canon has no priority axis — drop it (see canon.yml 'no_priority')" ;;
    area:*)
      echo "malformed area label — use lowercase kebab-case, e.g. area:shopping-list" ;;
    *)
      echo "use a canon type (bug enhancement documentation question technical-debt chore test-gap flaky-test ci-failure) or an area: label" ;;
  esac
}

echo "verify-canon: scanning skills/ and agents/ against $(wc -l <<< "$allowed") canon labels"

while IFS= read -r file; do
  # --label X, --label=X, --add-label X, --remove-label X (quoted or bare)
  while IFS=: read -r lineno match; do
    [ -z "${match:-}" ] && continue
    # Strip the opening quote/backtick, then everything from the closing one.
    # The trailing backtick matters: these files are markdown, so `--label bug`
    # inside inline code is the normal way a label appears here.
    label=$(sed -E 's/.*--(label|add-label|remove-label)[= ]+//; s/^["'"'"'`]//; s/["'"'"'`].*$//; s/[[:space:]].*$//; s/[,.)]+$//' <<< "$match")
    [ -z "$label" ] && continue
    case "$label" in '$'*|'{'*|'<'*|'') continue ;; esac   # placeholders, not literals
    is_allowed "$label" || report "${file#"$ROOT"/}" "$lineno" "'$label'" "$(hint_for "$label")"
  done < <(grep -nEo -- '--(label|add-label|remove-label)[= ]+["'"'"'`]?[A-Za-z$<{][^"'"'"'`[:space:]]*' "$file" 2>/dev/null)

  # labels: ["a", "b"]  (the MCP create_issue form)
  while IFS=: read -r lineno match; do
    [ -z "${match:-}" ] && continue
    while IFS= read -r label; do
      [ -z "$label" ] && continue
      case "$label" in '$'*|'{'*|'<'*) continue ;; esac
      is_allowed "$label" || report "${file#"$ROOT"/}" "$lineno" "'$label'" "$(hint_for "$label")"
    done < <(grep -oE '"[^"]+"' <<< "$match" | tr -d '"')
  done < <(grep -nEo 'labels: \[[^]]*\]' "$file" 2>/dev/null)
done < <(find "$ROOT/skills" "$ROOT/agents" -type f -name '*.md' 2>/dev/null | sort)

if [ "$fail" -gt 0 ]; then
  echo
  echo "verify-canon: FAILED — $fail label(s) outside the canon"
  echo "Canon: $CANON"
  exit 1
fi

echo "verify-canon: OK"
