#!/usr/bin/env bash
# Contract matrix for the review artefact's path and marker.
#
# Three skills have to agree on one filename: `code-reviewer` writes
# `.local-review.md`, `/ship` posts it at Stage 4, `pr-quality` re-posts it every
# round. Nothing at runtime checks that they agree — a caller pointed at the
# wrong path just finds no file and carries on, which is exactly the silent
# degradation the artefact exists to make visible.
#
# It also pins the marker spec. `assert-review-posted.sh` in the consuming repos
# and pr-quality's LAST_REVIEWED jq capture both parse
# `<!-- local-review sha=<40hex> -->`. That format is load-bearing across repos:
# changing it here turns their guards green-forever, which is worse than no guard.
#
# Run: ./artefact-path.test.sh   (resolves the skills dir from this script)
set -u
SKILLS="$(cd "$(dirname "$0")/../.." && pwd)"
REVIEWER="$SKILLS/code-reviewer/SKILL.md"
SHIP="$SKILLS/ship/SKILL.md"
PRQ="$SKILLS/pr-quality/SKILL.md"
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ✗ %s\n' "$1"; }

present() { # <desc> <file> <regex>
  if grep -Eq -- "$3" "$2"; then ok "$1"; else bad "$1 — no match for /$3/ in ${2##*/}"; fi
}

absent() { # <desc> <file> <regex>
  if grep -Eq -- "$3" "$2"; then bad "$1 — unexpected /$3/ in ${2##*/}"; else ok "$1"; fi
}

echo "== files exist =="
for f in "$REVIEWER" "$SHIP" "$PRQ"; do
  if [ -f "$f" ]; then ok "${f##*/} present ($(basename "$(dirname "$f")"))"; else bad "$f MISSING"; fi
done

echo "== one path constant, named by all three =="
for f in "$REVIEWER" "$SHIP" "$PRQ"; do
  present "$(basename "$(dirname "$f")") names .local-review.md" "$f" '\.local-review\.md'
done

echo "== code-reviewer is the writer =="
present "Step 6 writes the artefact to the file" "$REVIEWER" \
  'Write the artefact.*\.local-review\.md|Write it to .\.local-review\.md'
present "written byte-identical to what is emitted" "$REVIEWER" 'Byte-identical'
present "the file is gitignored" "$REVIEWER" "grep -qxF '\.local-review\.md' \.gitignore"
present "writer is this skill, not its callers" "$REVIEWER" 'is the writer, not its callers'

echo "== marker spec is unchanged (cross-repo contract) =="
present "marker template still in Step 6" "$REVIEWER" '<!-- local-review sha='
present "sha must be full 40-char" "$REVIEWER" 'full 40-character HEAD sha'
present "agents=<ran>/6 still specified" "$REVIEWER" 'agents=<ran>/6'
# The consumers parse a 40-hex sha; pin the class they match on.
present "ship parses a 40-hex sha" "$SHIP" '\[0-9a-f\]\\?\{40\\?\}'
present "pr-quality parses a 40-hex sha" "$PRQ" '\[0-9a-f\]\{40\}'

echo "== callers post the file, not a held block =="
present "ship posts with --body-file .local-review.md" "$SHIP" \
  'gh pr comment .* --body-file \.local-review\.md'
present "pr-quality posts with --body-file .local-review.md" "$PRQ" \
  'gh pr comment .* --body-file \.local-review\.md'
absent "ship no longer holds the artefact in conversation" "$SHIP" 'Hold the artefact'
# `--body` alongside the artefact is the shell-quoting mangle the skill warns
# about. Scoped to `.local-review.md` on purpose: pr-quality's decision-log
# comment legitimately uses `--body`, and a blanket ban would flag it.
absent "ship never posts .local-review.md with --body" "$SHIP" '--body +[^-].*\.local-review\.md'
absent "pr-quality never posts .local-review.md with --body" "$PRQ" '--body +[^-].*\.local-review\.md'

echo "== staleness guard =="
present "ship refuses a stale artefact" "$SHIP" 'STALE'
present "pr-quality refuses a stale artefact" "$PRQ" 'STALE'
for f in "$SHIP" "$PRQ"; do
  present "$(basename "$(dirname "$f")") compares marker sha to HEAD" "$f" 'git rev-parse HEAD'
done

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
