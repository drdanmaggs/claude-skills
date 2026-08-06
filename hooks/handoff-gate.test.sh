#!/usr/bin/env bash
# Offline test matrix for handoff-gate.sh — no Claude Code involved.
# Pipes synthetic PreToolUse payloads at the hook and asserts allow/deny.
# Run: ./handoff-gate.test.sh   (resolves the hook next to this script)
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/handoff-gate.sh"
PASS=0; FAIL=0

T="$(mktemp -d)"
mkdir -p "$T/repo/src/deep/nested" "$T/clean"
trap 'rm -rf "$T"' EXIT

arm()    { printf '| Constant | Value |\n' > "$T/repo/.tdd-session.md"; }
disarm() { rm -f "$T/repo/.tdd-session.md"; }

run_case() { # <desc> <ALLOW|DENY> <payload>
  local desc="$1" expect="$2" payload="$3" out decision
  out="$(printf '%s' "$payload" | "$HOOK" 2>/dev/null)"
  # Claude Code surfaces "hook error" on every matched call if a
  # hookSpecificOutput block omits hookEventName — including allow paths.
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

payload() { # <skill> <cwd>
  printf '{"tool_name":"Skill","cwd":"%s","tool_input":{"skill":"%s","args":"x"}}' "$2" "$1"
}

echo "== live TDD session: the three chaining skills are denied =="
arm
run_case "Skill(claude-skills:ship)       -> DENY" DENY "$(payload claude-skills:ship "$T/repo")"
run_case "Skill(claude-skills:tdd)        -> DENY" DENY "$(payload claude-skills:tdd "$T/repo")"
run_case "Skill(claude-skills:pr-quality) -> DENY" DENY "$(payload claude-skills:pr-quality "$T/repo")"

echo "== bare (unscoped) names match too =="
run_case "Skill(ship)       -> DENY" DENY "$(payload ship "$T/repo")"
run_case "Skill(tdd)        -> DENY" DENY "$(payload tdd "$T/repo")"
run_case "Skill(pr-quality) -> DENY" DENY "$(payload pr-quality "$T/repo")"

echo "== live session: everything else still runs =="
# code-reviewer is invoked BY /ship mid-run; denying it would break the chain
# this gate is meant to protect.
run_case "Skill(claude-skills:code-reviewer) -> ALLOW" ALLOW "$(payload claude-skills:code-reviewer "$T/repo")"
run_case "Skill(claude-skills:create-pr)     -> ALLOW" ALLOW "$(payload claude-skills:create-pr "$T/repo")"
run_case "Skill(claude-skills:issue-scope)   -> ALLOW" ALLOW "$(payload claude-skills:issue-scope "$T/repo")"
run_case "Skill(worktree-reset)              -> ALLOW" ALLOW "$(payload worktree-reset "$T/repo")"

echo "== signal is found from a nested cwd =="
run_case "nested cwd, Skill(ship) -> DENY" DENY "$(payload ship "$T/repo/src/deep/nested")"

echo "== no live session: all three allowed (the whole point) =="
disarm
run_case "no session, Skill(ship)       -> ALLOW" ALLOW "$(payload ship "$T/repo")"
run_case "no session, Skill(tdd)        -> ALLOW" ALLOW "$(payload tdd "$T/repo")"
run_case "no session, Skill(pr-quality) -> ALLOW" ALLOW "$(payload pr-quality "$T/repo")"
run_case "unrelated dir, Skill(ship)    -> ALLOW" ALLOW "$(payload ship "$T/clean")"

echo "== other tools are invisible to this hook =="
arm
run_case "tool_name=Bash            -> ALLOW" ALLOW \
  "$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"ship"}}' "$T/repo")"
run_case "tool_name=Edit            -> ALLOW" ALLOW \
  "$(printf '{"tool_name":"Edit","cwd":"%s","tool_input":{"file_path":"%s/src/a.ts"}}' "$T/repo" "$T/repo")"

echo "== degrades quietly (fails open) =="
run_case "malformed JSON        -> ALLOW" ALLOW 'not json at all'
run_case "empty input           -> ALLOW" ALLOW ''
run_case "no tool_name          -> ALLOW" ALLOW "$(printf '{"cwd":"%s"}' "$T/repo")"
run_case "no tool_input.skill   -> ALLOW" ALLOW "$(printf '{"tool_name":"Skill","cwd":"%s","tool_input":{}}' "$T/repo")"
run_case "missing cwd           -> ALLOW" ALLOW '{"tool_name":"Skill","tool_input":{"skill":"ship"}}'
run_case "nonexistent cwd       -> ALLOW" ALLOW "$(payload ship "$T/does-not-exist")"

echo "== denial names its own bypass =="
out="$(printf '%s' "$(payload ship "$T/repo")" | "$HOOK" 2>/dev/null)"
if echo "$out" | grep -q "rm $T/repo/.tdd-session.md"; then
  PASS=$((PASS+1)); printf '  ✓ denial message includes the rm bypass\n'
else
  FAIL=$((FAIL+1)); printf '  ✗ denial message omits the rm bypass\n     out: %s\n' "$out"
fi
if echo "$out" | grep -q '/clear'; then
  PASS=$((PASS+1)); printf '  ✓ denial message names /clear\n'
else
  FAIL=$((FAIL+1)); printf '  ✗ denial message omits /clear\n'
fi
# The reason is JSON-encoded, so a path with a quote or backslash cannot break out.
if echo "$out" | jq -e '.hookSpecificOutput.permissionDecisionReason | type == "string"' >/dev/null 2>&1; then
  PASS=$((PASS+1)); printf '  ✓ output is valid JSON with a string reason\n'
else
  FAIL=$((FAIL+1)); printf '  ✗ output is not valid JSON\n     out: %s\n' "$out"
fi

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
