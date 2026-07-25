#!/usr/bin/env bash
# tdd-gate.sh — PreToolUse (Edit|Write|MultiEdit) gate enforcing TDD phase discipline.
# Shipped by the rocket-fuel plugin; registered via hooks/hooks.json.
#
# Reads a `.tdd-phase` file at the repo root (RED|GREEN|REFACTOR). Absent => invisible.
#   RED      : may edit tests, NOT source  (write the failing test first)
#   GREEN    : may edit source, NOT tests  (fix the impl, not the test)
#   REFACTOR : may edit source, NOT tests  (keep the contract green)
# Always allows the .tdd-phase file and .md/plan bookkeeping.
# Minimal content ban: refuses edits that add `.only(` or `.skip(`.
# Logs every active invocation to ~/.claude/tdd-gate.log for observability.

input=$(cat)

# No jq -> don't get in the way.
command -v jq >/dev/null 2>&1 || { printf '{"hookSpecificOutput":{}}'; exit 0; }

neutral() { printf '{"hookSpecificOutput":{}}'; exit 0; }

tool=$(echo "$input" | jq -r '.tool_name // "?"')
fp=$(echo "$input"  | jq -r '.tool_input.file_path // .tool_input.path // ""')
[ -z "$fp" ] && neutral

# Walk up from the edited file to find the repo's .tdd-phase
dir=$(dirname "$fp"); phase_file=""
while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
  if [ -f "$dir/.tdd-phase" ]; then phase_file="$dir/.tdd-phase"; break; fi
  dir=$(dirname "$dir")
done
[ -z "$phase_file" ] && neutral            # gate not active for this repo

phase=$(tr -d '[:space:]' < "$phase_file")
base=$(basename "$fp")
content=$(echo "$input" | jq -r '.tool_input.new_string // .tool_input.content // ""')

log()   { echo "$(date +%H:%M:%S) tool=$tool phase=${phase:-none} fp=$fp -> $1" >> "$HOME/.claude/tdd-gate.log"; }
allow() { log ALLOW; printf '{"hookSpecificOutput":{}}'; exit 0; }
deny()  { log "DENY: $1"; printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$1"; exit 0; }

# Bookkeeping is always allowed
[ "$base" = ".tdd-phase" ] && allow
case "$fp" in *.md) allow ;; esac

# Minimal content ban (any phase)
case "$content" in
  *".only("*) deny "TDD: refusing to add .only( — it silently disables sibling tests." ;;
  *".skip("*) deny "TDD: refusing to add .skip( — don't skip the test you're meant to make pass." ;;
esac

# Classify test vs source
# False positive: shellcheck treats */__tests__/* and */tests/* as subsuming each
# other, but neither matches the other's paths (/repo/tests/x.ts has no /__tests__/,
# /repo/__tests__/x.ts has no /tests/). Both are reachable and both are covered by
# the test matrix. Not fixable without dropping a case we need.
# shellcheck disable=SC2221,SC2222
case "$fp" in
  # *.test.* / *.spec.* cover JS/TS; *_test.* covers Go, Rust and foo_test.py
  # (worker_test.go) — Go is the convention Rocket Fuel itself uses.
  *.test.*|*.spec.*|*_test.*|*/__tests__/*|*/tests/*|*/supabase/tests/*) is_test=1 ;;
  *) is_test=0 ;;
esac

case "$phase" in
  RED)
    [ "$is_test" = 0 ] && deny "TDD RED: write the failing test first — edit tests only. Set .tdd-phase=GREEN once it fails, then edit source."
    allow ;;
  GREEN|REFACTOR)
    [ "$is_test" = 1 ] && deny "TDD $phase: don't edit tests now — fix the implementation. (Set .tdd-phase=RED to change the contract.)"
    allow ;;
  *)
    neutral ;;   # unknown phase value -> stay out of the way
esac
