#!/usr/bin/env bash
# Contract matrix for the /tdd session-state files.
#
# `.tdd-phase` and `.tdd-session.md` are only useful if the skill names the SAME
# filename at all four points of their lifecycle: armed in .gitignore, written,
# read by subagents, torn down at Completion. A rename or a typo in any one of
# them fails silently at runtime — the orchestrator writes one path and the
# subagent reads another, and nothing errors, it just quietly has no constants.
#
# So this greps the prose. It is a contract test over documentation, which is an
# odd thing until you notice the documentation IS the program here.
#
# Run: ./session-file.test.sh   (resolves the skill next to this script)
set -u
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$SKILL_DIR/SKILL.md"
PROMPTS="$SKILL_DIR/references/phase-prompts.md"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  ✗ %s\n' "$1"; }

# present <desc> <file> <extended-regex>
present() {
  if grep -Eq -- "$3" "$2"; then ok "$1"; else bad "$1 — no match for /$3/ in ${2##*/}"; fi
}

# absent <desc> <file> <extended-regex>
absent() {
  if grep -Eq -- "$3" "$2"; then
    bad "$1 — unexpected match for /$3/ in ${2##*/}"
  else
    ok "$1"
  fi
}

# count_at_least <desc> <file> <extended-regex> <n>
count_at_least() {
  local n
  n="$(grep -Ec -- "$3" "$2" || true)"
  if [ "$n" -ge "$4" ]; then ok "$1 ($n)"; else bad "$1 — found $n, want >= $4"; fi
}

echo "== files exist =="
for f in "$SKILL" "$PROMPTS"; do
  if [ -f "$f" ]; then ok "${f##*/} present"; else bad "${f##*/} MISSING"; fi
done

echo "== .tdd-session.md lifecycle: arm =="
present "gitignore loop names .tdd-session.md" "$SKILL" '\.tdd-session\.md'
present "gitignore loop covers all three state files" "$SKILL" \
  'for f in \.tdd-phase \.tdd-session\.md \.local-review\.md'

echo "== .tdd-session.md lifecycle: write =="
present "Session Constants section writes the file" "$SKILL" \
  'Write the resolved table to .\.tdd-session\.md'
present "written before the first spawn" "$SKILL" 'before the first subagent spawn'
present "Stage 0f appends Acceptance test path" "$SKILL" \
  'Acceptance test path.*>> \.tdd-session\.md'

echo "== .tdd-session.md lifecycle: read =="
present "phase-prompts points briefs at the file" "$PROMPTS" \
  'Session constants: \.tdd-session\.md'
# Five templates spawn subagents: acceptance, PREP, RED, GREEN, REFACTOR.
count_at_least "every spawning template names the file" "$PROMPTS" \
  '^ *Session constants: \.tdd-session\.md' 5
# If a template still re-pastes a session constant, the file has a rival.
absent "no template re-pastes {test_command}" "$PROMPTS" '^ *Test command: \{test_command\}'
absent "no template re-pastes {standards_path}" "$PROMPTS" 'Standards file: \{standards_path\}'

echo "== .tdd-session.md lifecycle: teardown =="
present "Completion removes both state files" "$SKILL" \
  'rm -f \.tdd-phase \.tdd-session\.md'
present "teardown explicitly spares .local-review.md" "$SKILL" \
  'Leave .\.local-review\.md. alone'

echo "== .tdd-phase lifecycle still intact (regression) =="
present "phase file is written before the spawn" "$SKILL" "printf 'RED' > \.tdd-phase"
present "phase gate hook is still described" "$SKILL" 'hooks/tdd-gate\.sh'
present "phase declaration is still a hard gate" "$SKILL" 'Phase declaration gate'

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
