#!/usr/bin/env bash
# Offline test matrix for generate_coverage.sh — no vitest, no network.
# Stubs `npx` on PATH and asserts the exact argv the script builds, so the
# command construction is verifiable without running a real coverage pass.
# Run: ./generate_coverage.test.sh
set -u
SCRIPT="$(cd "$(dirname "$0")" && pwd)/generate_coverage.sh"
PASS=0; FAIL=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/stub"

# Records argv one-per-line, then succeeds. `exit 0` matters: under `set -e` a
# failing npx would mask anything the shell went on to do with the rest of the
# command line, which is exactly what the injection cases need to observe.
cat > "$T/stub/npx" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGV_OUT"
exit 0
STUB
chmod +x "$T/stub/npx"

BASE='vitest
run
--coverage
--coverage.enabled=true
--coverage.reporter=json
--coverage.reporter=html
--coverage.reportsDirectory=./coverage'

run_case() { # <desc> <expected_argv> <args...>
  local desc="$1" expect="$2"; shift 2
  local out
  ARGV_OUT="$T/argv" PATH="$T/stub:$PATH" bash "$SCRIPT" "$@" >/dev/null 2>&1
  out="$(cat "$T/argv" 2>/dev/null)"
  if [ "$out" = "$expect" ]; then
    PASS=$((PASS+1)); printf '  ✓ %s\n' "$desc"
  else
    FAIL=$((FAIL+1))
    printf '  ✗ %s\n     expected: %s\n     got:      %s\n' \
      "$desc" "$(tr '\n' '·' <<< "$expect")" "$(tr '\n' '·' <<< "$out")"
  fi
  rm -f "$T/argv"
}

assert_no_file() { # <desc> <path>
  if [ -e "$2" ]; then
    FAIL=$((FAIL+1)); printf '  ✗ %s — side effect executed: %s\n' "$1" "$2"; rm -f "$2"
  else
    PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"
  fi
}

echo "== scope handling =="
run_case "no args -> scope '.'"        "$BASE
."
run_case "explicit scope"              "$BASE
lib/" "lib/"
run_case "scope containing a space"    "$BASE
my lib/" "my lib/"

echo "== skip patterns become --exclude pairs =="
run_case "one skip"    "$BASE
lib/
--exclude
**/a.test.ts" "lib/" "a.test.ts"
run_case "three skips" "$BASE
lib/
--exclude
**/a.test.ts
--exclude
**/b.test.ts
--exclude
**/c.test.ts" "lib/" "a.test.ts|b.test.ts|c.test.ts"
run_case "empty skip pattern is ignored" "$BASE
lib/" "lib/" ""

echo "== arguments are data, never code =="
# `eval` re-parses the assembled string, so anything that survives quoting in
# $1/$2 executes. These are the cases the array form exists to make impossible.
#
# The single quotes below are load-bearing and SC2016 is wrong about them here:
# the test's whole purpose is that the LITERAL text `$HOME` reaches the script
# unexpanded. Expanding it in the test would assert nothing. Not fixable —
# suppressing per-case rather than for the file so a real SC2016 elsewhere in
# this test still gets caught.
# shellcheck disable=SC2016
run_case "\$ in scope stays literal"  "$BASE
lib/\$HOME" 'lib/$HOME'
# shellcheck disable=SC2016
run_case "backtick in scope stays literal" "$BASE
lib/\`id\`" 'lib/`id`'
# shellcheck disable=SC2016
run_case "\$() in skip stays literal" "$BASE
lib/
--exclude
**/\$(id).test.ts" "lib/" '$(id).test.ts'

PWNED="$T/PWNED"
ARGV_OUT="$T/argv" PATH="$T/stub:$PATH" bash "$SCRIPT" "x\"; touch $PWNED; echo \"" >/dev/null 2>&1
assert_no_file "command injection via scope is inert" "$PWNED"

ARGV_OUT="$T/argv" PATH="$T/stub:$PATH" bash "$SCRIPT" "lib/" "x\"; touch $PWNED; echo \"" >/dev/null 2>&1
assert_no_file "command injection via skip pattern is inert" "$PWNED"

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
