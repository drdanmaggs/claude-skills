#!/usr/bin/env bash
# Offline test matrix for tdd-gate.sh — no Claude Code involved.
# Pipes synthetic PreToolUse payloads at the hook and asserts allow/deny.
# Run: ./tdd-gate.test.sh   (resolves the hook next to this script)
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/tdd-gate.sh"
PASS=0; FAIL=0

T="$(mktemp -d)"
mkdir -p "$T/src" "$T/tests" "$T/docs/plans" "$T/internal/worker" "$T/__tests__"
trap 'rm -rf "$T"' EXIT

set_phase()   { printf '%s' "$1" > "$T/.tdd-phase"; }
clear_phase() { rm -f "$T/.tdd-phase"; }

run_case() { # <desc> <ALLOW|DENY> <payload>
  local desc="$1" expect="$2" payload="$3" out decision
  out="$(printf '%s' "$payload" | "$HOOK" 2>/dev/null)"
  # Claude Code rejects a hookSpecificOutput block that omits hookEventName and
  # surfaces "hook error" in the UI on every matched call — including allow paths.
  if echo "$out" | grep -q '"hookSpecificOutput"' && ! echo "$out" | grep -q '"hookEventName"'; then
    FAIL=$((FAIL+1))
    printf '  ✗ %s — hookSpecificOutput missing hookEventName\n     out: %s\n' "$desc" "$out"
    return
  fi
  if echo "$out" | grep -q '"permissionDecision":"deny"'; then decision=DENY; else decision=ALLOW; fi
  if [ "$decision" = "$expect" ]; then
    PASS=$((PASS+1)); printf '  ✓ %s\n' "$desc"
  else
    FAIL=$((FAIL+1)); printf '  ✗ %s — expected %s got %s\n     out: %s\n' "$desc" "$expect" "$decision" "$out"
  fi
}

payload() { # <tool> <file_path> [content]
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s","content":"%s","new_string":"%s"}}' \
    "$1" "$2" "${3:-}" "${3:-}"
}

echo "== RED phase =="
set_phase RED
run_case "RED: edit test file  -> ALLOW" ALLOW "$(payload Edit "$T/tests/foo.test.ts")"
run_case "RED: edit source     -> DENY"  DENY  "$(payload Edit "$T/src/foo.ts")"
run_case "RED: edit plan .md   -> ALLOW" ALLOW "$(payload Edit "$T/docs/plans/p.md")"
run_case "RED: write .tdd-phase-> ALLOW" ALLOW "$(payload Write "$T/.tdd-phase")"

echo "== GREEN phase =="
set_phase GREEN
run_case "GREEN: edit source    -> ALLOW" ALLOW "$(payload Edit "$T/src/foo.ts")"
run_case "GREEN: edit test file -> DENY"  DENY  "$(payload Edit "$T/tests/foo.test.ts")"

echo "== REFACTOR phase =="
set_phase REFACTOR
run_case "REFACTOR: edit source    -> ALLOW" ALLOW "$(payload Edit "$T/src/foo.ts")"
run_case "REFACTOR: edit test file -> DENY"  DENY  "$(payload Edit "$T/tests/foo.test.ts")"

echo "== Go test-file naming (foo_test.go, not foo.test.go) =="
set_phase RED
run_case "RED: edit *_test.go   -> ALLOW" ALLOW "$(payload Edit "$T/internal/worker/worker_test.go")"
run_case "RED: edit *.go source -> DENY"  DENY  "$(payload Edit "$T/internal/worker/worker.go")"
set_phase GREEN
run_case "GREEN: edit *.go source -> ALLOW" ALLOW "$(payload Edit "$T/internal/worker/worker.go")"
run_case "GREEN: edit *_test.go   -> DENY"  DENY  "$(payload Edit "$T/internal/worker/worker_test.go")"

echo "== directory-based classification (both patterns reachable) =="
set_phase RED
run_case "RED: edit tests/helpers.ts     -> ALLOW" ALLOW "$(payload Edit "$T/tests/helpers.ts")"
run_case "RED: edit __tests__/helpers.ts -> ALLOW" ALLOW "$(payload Edit "$T/__tests__/helpers.ts")"

echo "== content bans (minimal) =="
set_phase RED
run_case "RED: add .only( to test -> DENY"  DENY  "$(payload Edit "$T/tests/foo.test.ts" "it.only(")"
run_case "RED: add .skip( to test -> DENY"  DENY  "$(payload Edit "$T/tests/foo.test.ts" "it.skip(")"
run_case "RED: normal test edit   -> ALLOW" ALLOW "$(payload Edit "$T/tests/foo.test.ts" "expect(x).toBe(1)")"

echo "== invisible when no .tdd-phase =="
clear_phase
run_case "no phase: edit source -> ALLOW" ALLOW "$(payload Edit "$T/src/foo.ts")"
run_case "no phase: edit test   -> ALLOW" ALLOW "$(payload Edit "$T/tests/foo.test.ts")"

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
