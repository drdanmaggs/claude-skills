#!/usr/bin/env bash
# Offline test matrix for verify_target.sh — no vitest, no network.
#
# Runs the script the way SKILL.md documents it: from a PROJECT directory,
# invoking the skill by path. `npx` is stubbed to drop a fixture coverage
# report, so the real generate_coverage.sh runs end to end without vitest.
# Run: ./verify_target.test.sh
set -u
SCRIPT="$(cd "$(dirname "$0")" && pwd)/verify_target.sh"
PASS=0; FAIL=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/stub" "$T/proj/scripts"

# lib/  -> 6 statements, 4 covered = 66.7%
# app/  -> 2 statements, 0 covered = 0.0%
cat > "$T/fixture.json" <<'JSON'
{
  "/proj/lib/a.ts": { "s": { "0": 1, "1": 1, "2": 0, "3": 1 } },
  "/proj/lib/b.ts": { "s": { "0": 1, "1": 0 } },
  "/proj/app/c.ts": { "s": { "0": 0, "1": 0 } }
}
JSON

cat > "$T/stub/npx" <<STUB
#!/usr/bin/env bash
mkdir -p ./coverage
cp "$T/fixture.json" ./coverage/coverage-final.json
exit 0
STUB
chmod +x "$T/stub/npx"

# A broken \`bc\`. The script must not need it — bc is absent from many minimal
# images, and the whole calculation can happen in the Python call that is
# already running.
cat > "$T/stub/bc" <<'STUB'
#!/usr/bin/env bash
echo "bc: not available" >&2
exit 127
STUB
chmod +x "$T/stub/bc"

# A decoy at the path the script used to hardcode (./scripts/generate_coverage.sh).
# If it runs, the script resolved its sibling against the caller's cwd instead
# of its own directory — which is the documented invocation, and was broken.
cat > "$T/proj/scripts/generate_coverage.sh" <<STUB
#!/usr/bin/env bash
touch "$T/proj/DECOY_RAN"
mkdir -p ./coverage
cp "$T/fixture.json" ./coverage/coverage-final.json
exit 0
STUB
chmod +x "$T/proj/scripts/generate_coverage.sh"

reset_proj() { rm -rf "$T/proj/coverage" "$T/proj/DECOY_RAN"; }

run_case() { # <desc> <expect_exit> <expect_substring> <args...>
  local desc="$1" xcode="$2" xstr="$3"; shift 3
  local out code
  reset_proj
  out="$(cd "$T/proj" && PATH="$T/stub:$PATH" bash "$SCRIPT" "$@" 2>&1)"; code=$?
  if [ "$code" = "$xcode" ] && [[ "$out" == *"$xstr"* ]]; then
    PASS=$((PASS+1)); printf '  ✓ %s\n' "$desc"
  else
    FAIL=$((FAIL+1))
    printf '  ✗ %s — expected exit %s containing %q, got exit %s\n     out: %s\n' \
      "$desc" "$xcode" "$xstr" "$code" "$(tr '\n' '·' <<< "$out")"
  fi
}

echo "== target comparison =="
run_case "above target -> exit 0"    0 "66.7" 60 "lib/"
run_case "below target -> exit 1"    1 "66.7" 80 "lib/"
run_case "exactly at target -> exit 0" 0 "66.7" 66.7 "lib/"
run_case "reports the gap when short" 1 "13.3" 80 "lib/"
run_case "defaults to target 80"     1 "66.7" "" "lib/"

echo "== scope filtering =="
run_case "scope selects a subtree"   1 "0.0" 50 "app/"
run_case "scope matching nothing -> 0.0" 1 "0.0" 50 "zzz/"

echo "== does not depend on bc =="
# Guaranteed by the broken `bc` stub on PATH for every case above; this one
# just makes the intent explicit and fails loudly if bc creeps back in.
run_case "works with bc unavailable" 0 "66.7" 60 "lib/"

echo "== resolves its sibling script, not the caller's =="
reset_proj
(cd "$T/proj" && PATH="$T/stub:$PATH" bash "$SCRIPT" 60 "lib/" >/dev/null 2>&1)
if [ -e "$T/proj/DECOY_RAN" ]; then
  FAIL=$((FAIL+1)); printf '  ✗ ran ./scripts/generate_coverage.sh from the caller cwd\n'
else
  PASS=$((PASS+1)); printf '  ✓ ran generate_coverage.sh from the skill directory\n'
fi

echo "== scope is data, never code =="
# The scope was interpolated straight into Python source, so an apostrophe
# closed the string literal and anything after it was parsed as Python.
run_case "apostrophe in scope does not break parsing" 1 "0.0" 50 "lib/o'brien"
run_case "double quote in scope is literal"           1 "0.0" 50 'lib/say"hi'

PWNED="$T/PWNED"
reset_proj
(cd "$T/proj" && PATH="$T/stub:$PATH" bash "$SCRIPT" 50 "x' if __import__('os').system('touch $PWNED') else 'y" >/dev/null 2>&1)
if [ -e "$PWNED" ]; then
  FAIL=$((FAIL+1)); printf '  ✗ python injection via scope executed\n'; rm -f "$PWNED"
else
  PASS=$((PASS+1)); printf '  ✓ python injection via scope is inert\n'
fi

echo "== missing coverage report =="
reset_proj
cat > "$T/stub/npx" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$T/stub/npx"
out="$(cd "$T/proj" && PATH="$T/stub:$PATH" bash "$SCRIPT" 80 "lib/" 2>&1)"; code=$?
if [ "$code" != 0 ] && [[ "$out" == *"not found"* ]]; then
  PASS=$((PASS+1)); printf '  ✓ missing coverage file fails with a message\n'
else
  FAIL=$((FAIL+1)); printf '  ✗ missing coverage file — exit %s: %s\n' "$code" "$(tr '\n' '·' <<< "$out")"
fi

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
