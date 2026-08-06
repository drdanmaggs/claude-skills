#!/usr/bin/env bash
# Contract matrix for the skill-handoff hard stops.
#
# handoff-gate.sh enforces this mechanically, but the gate is a backstop, not the
# design: it only fires while `.tdd-session.md` exists, so /issue-scope -> /tdd
# (which happens before any TDD session exists) is covered by prose alone. That
# prose is therefore load-bearing, and prose degrades silently — the documented
# lesson behind /ship's review artefact.
#
# Lives under skills/tdd/ because /tdd is the hub: it is the inbound end of the
# issue-scope handoff and the outbound end of the ship one.
#
# Run: ./handoff-stop.test.sh
set -u
SKILLS="$(cd "$(dirname "$0")/../.." && pwd)"
ROOT="$(cd "$SKILLS/.." && pwd)"
TDD="$SKILLS/tdd/SKILL.md"
SCOPE="$SKILLS/issue-scope/SKILL.md"
HOOKS_JSON="$ROOT/hooks/hooks.json"
PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ✗ %s\n' "$1"; }

# Patterns below write `.` where the prose has a markdown backtick. A literal
# backtick inside a single-quoted string trips SC2016, and CI lints at default
# severity, so an info-level finding is a red build. `.` matches the backtick.
# (Keep the word "shellcheck" off the start of a comment line here — it gets
#  parsed as a directive, which is SC1072/SC1073 and also a red build.)
present() { # <desc> <file> <regex>
  if grep -Eq -- "$3" "$2"; then ok "$1"; else bad "$1 — no match for /$3/ in ${2##*/}"; fi
}
absent() { # <desc> <file> <regex>
  if grep -Eq -- "$3" "$2"; then bad "$1 — unexpected /$3/ in ${2##*/}"; else ok "$1"; fi
}

# no_imperative <desc> <file> <regex>
#
# The stop prose has to NAME the call it forbids ("Do not invoke Skill(ship)"),
# so a plain absence check on the call is unsatisfiable. Match the call, then
# drop the lines that negate it, and assert nothing survives — that residue is
# an actual instruction to chain.
no_imperative() {
  local hits
  hits="$(grep -En -- "$3" "$2" | grep -Eiv 'do not|don.t|never|instead of|no longer|rather than')" || true
  if [ -z "$hits" ]; then
    ok "$1"
  else
    bad "$1 — surviving imperative in ${2##*/}:"
    printf '     %s\n' "$hits"
  fi
}

echo "== /issue-scope no longer invokes /tdd =="
no_imperative "no surviving Skill(\"tdd\") call"       "$SCOPE" 'Skill\("tdd"\)|Skill\(tdd\)'
no_imperative "no surviving 'invoke /tdd' instruction" "$SCOPE" 'invoke .?/tdd'
present "says Do not invoke /tdd"      "$SCOPE" '\*\*Do not invoke ./tdd.\.\*\*'
present "instructs /clear then /tdd"   "$SCOPE" 'Run ./clear., then ./tdd'
present "explains the cost"            "$SCOPE" '537k|200k tokens'

echo "== /issue-scope Phase 6 hands back and stops =="
present "epic handback instructs /clear" "$SCOPE" 'Run ./clear., then ./issue-scope'
absent  "does not self-invoke on a child" "$SCOPE" 'invoke ./issue-scope. on a child yourself\.$'

echo "== /tdd no longer invokes /ship =="
no_imperative "no surviving Skill(\"ship\") call"      "$TDD" 'Skill\("ship"\)|Skill\(ship\)'
no_imperative "no surviving Skill(\"pr-quality\") call" "$TDD" 'Skill\("pr-quality"\)|Skill\(pr-quality\)'
present "explicitly refuses to invoke it" "$TDD" 'Do not invoke .Skill\("ship"\).'
present "bug-fix mode instructs /clear"   "$TDD" 'Run ./clear., then ./ship.'
present "feature mode instructs /clear"   "$TDD" 'run ./clear., then ./ship.'
present "both modes stop"                 "$TDD" 'The session ends here, in both modes'

echo "== teardown happens before the stop =="
# Ordering matters: the gate reads .tdd-session.md, so a stop that fires before
# teardown would block the very /ship it just told the user to run.
present "teardown section exists" "$TDD" 'Tear Down the Session State'
present "teardown is after the acceptance gate" "$TDD" 'after the acceptance gate'
td=$(grep -n 'rm -f \.tdd-phase \.tdd-session\.md' "$TDD" | head -1 | cut -d: -f1)
st=$(grep -n 'The session ends here, in both modes' "$TDD" | head -1 | cut -d: -f1)
if [ -n "$td" ] && [ -n "$st" ] && [ "$td" -lt "$st" ]; then
  ok "teardown (line $td) precedes the stop (line $st)"
else
  bad "teardown must precede the stop — teardown=${td:-none} stop=${st:-none}"
fi

echo "== per-slice compact is a recommendation, not a stop =="
present "recommends /compact at the slice boundary" "$TDD" 'recommend a compact|Good point to ./compact'
present "carries a focus argument"                  "$TDD" '/compact keep the plan path'
present "explicitly not a stop"                     "$TDD" 'A recommendation, not a stop'

echo "== the gate is wired =="
present "handoff-gate registered in hooks.json" "$HOOKS_JSON" 'handoff-gate\.sh'
present "matcher is the Skill tool"             "$HOOKS_JSON" '"matcher": "\^Skill\$"'
present "uses CLAUDE_PLUGIN_ROOT"               "$HOOKS_JSON" '\$\{CLAUDE_PLUGIN_ROOT\}/hooks/handoff-gate\.sh'
present "top-level description names it"        "$HOOKS_JSON" 'handoff gate'
if command -v jq >/dev/null 2>&1; then
  if jq -e '.hooks.PreToolUse[] | select(.matcher=="^Skill$") | .hooks[0].timeout == 5' "$HOOKS_JSON" >/dev/null 2>&1; then
    ok "timeout is 5"
  else
    bad "timeout is not 5"
  fi
  v=$(jq -r '.version' "$PLUGIN_JSON")
  # The runtime loads from plugins/cache/claude-skills/claude-skills/<version>/,
  # so the bump is what makes the live build identifiable.
  if [ "$v" != "0.3.0" ]; then ok "plugin version bumped past 0.3.0 ($v)"; else bad "plugin version still 0.3.0"; fi
else
  ok "jq absent — skipped 2 JSON assertions"
fi

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
