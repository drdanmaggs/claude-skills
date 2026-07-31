#!/usr/bin/env bash
# Offline test matrix for pnpm-install-session-start.sh — no Claude Code, and
# no real pnpm. A stub `pnpm` is put first on PATH and touches a marker file,
# so each case can assert whether an install WOULD have run.
# Run: ./pnpm-install-session-start.test.sh   (resolves the hook next to it)
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/pnpm-install-session-start.sh"
PASS=0; FAIL=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# --- stub pnpm -------------------------------------------------------------
STUB="$T/bin"
mkdir -p "$STUB"
cat > "$STUB/pnpm" <<'EOF'
#!/usr/bin/env bash
echo "STUB pnpm $*" >> "$PNPM_MARKER"
exit "${PNPM_EXIT:-0}"
EOF
chmod +x "$STUB/pnpm"
export PATH="$STUB:$PATH"

# --- fixture builders ------------------------------------------------------
# make_project <name> <state>
#   none     : lockfile, no node_modules            -> install expected
#   current  : stamp NEWER than lockfile            -> no install
#   stale    : lockfile NEWER than stamp            -> install expected
#   equal    : identical mtimes                     -> no install (not "newer")
make_project() {
  local dir="$T/$1" state="$2"
  mkdir -p "$dir"
  : > "$dir/pnpm-lock.yaml"
  case "$state" in
    none) ;;
    current)
      mkdir -p "$dir/node_modules"
      touch -d '2020-01-01 00:00:00' "$dir/pnpm-lock.yaml"
      touch -d '2020-01-02 00:00:00' "$dir/node_modules/.modules.yaml"
      ;;
    stale)
      mkdir -p "$dir/node_modules"
      touch -d '2020-01-02 00:00:00' "$dir/pnpm-lock.yaml"
      touch -d '2020-01-01 00:00:00' "$dir/node_modules/.modules.yaml"
      ;;
    equal)
      mkdir -p "$dir/node_modules"
      touch -d '2020-01-01 00:00:00' "$dir/pnpm-lock.yaml"
      touch -d '2020-01-01 00:00:00' "$dir/node_modules/.modules.yaml"
      ;;
  esac
  printf '%s' "$dir"
}

run_case() { # <desc> <INSTALL|SKIP> <cwd> [env assignments...]
  local desc="$1" expect="$2" cwd="$3"; shift 3
  local marker="$T/marker.$RANDOM"
  : > "$marker"
  local status actual
  # shellcheck disable=SC2086 # deliberate: extra env assignments are optional
  printf '{"cwd":"%s"}' "$cwd" \
    | env PNPM_MARKER="$marker" "$@" "$HOOK" >/dev/null 2>&1
  status=$?
  if [ -s "$marker" ]; then actual=INSTALL; else actual=SKIP; fi

  if [ "$actual" = "$expect" ] && [ "$status" -eq 0 ]; then
    PASS=$((PASS+1)); printf '  ✓ %s\n' "$desc"
  else
    FAIL=$((FAIL+1))
    printf '  ✗ %s — expected %s/exit 0, got %s/exit %s\n' "$desc" "$expect" "$actual" "$status"
  fi
}

echo "== staleness detection =="
run_case "no node_modules            -> INSTALL" INSTALL "$(make_project p_none none)"
run_case "lockfile newer than stamp  -> INSTALL" INSTALL "$(make_project p_stale stale)"
run_case "stamp newer than lockfile  -> SKIP"    SKIP    "$(make_project p_current current)"
run_case "identical mtimes           -> SKIP"    SKIP    "$(make_project p_equal equal)"

echo "== only acts on pnpm projects =="
mkdir -p "$T/p_notpnpm"
run_case "no pnpm-lock.yaml          -> SKIP" SKIP "$T/p_notpnpm"
run_case "cwd does not exist         -> SKIP" SKIP "$T/does_not_exist"
run_case "empty cwd                  -> SKIP" SKIP ""

echo "== never runs in CI =="
run_case "CI=true, stale project     -> SKIP" SKIP "$(make_project p_ci stale)" CI=true

echo "== a failing install still exits 0 (must never break a session) =="
run_case "pnpm exits 1               -> INSTALL" INSTALL "$(make_project p_fail stale)" PNPM_EXIT=1

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
