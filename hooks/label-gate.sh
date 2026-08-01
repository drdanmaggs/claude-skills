#!/usr/bin/env bash
# label-gate.sh — PreToolUse gate keeping GitHub issue labels honest.
# Shipped by the claude-skills plugin; registered via hooks/hooks.json.
#
# Two invariants, both of which have failed in practice:
#   1. An issue must be created WITH a label. Measured: 40% of open issues in
#      productivity-coach-mvp and 90% in the smaller repos carry none.
#   2. A label must not be CREATED without the user approving it. Measured:
#      taxonomies of 38 and 28 labels with three parallel priority systems.
#
# Deliberately syntactic. It checks that a label was passed, not that the label
# is sensible — GitHub's API already rejects unknown labels, so semantic
# validation would cost a network call inside a 5s timeout for nothing.
# Canon conformance for labels hard-coded into skills is enforced separately by
# skills/issue-labeller/scripts/verify-canon.sh in CI.
#
# Active in every repo by default. "An issue has a label" is an invariant, not
# a mode you opt into — the repos that need it most would never opt in.
# Opt out per repo with `enforce: false` in .github/claude-labels.yml, or per
# call with a CLAUDE_LABELS_SKIP=1 prefix.
#
# Logs every active decision to ~/.claude/label-gate.log, including its own
# path, so a stale plugin-cache copy is identifiable from one log line.

input=$(cat)

# No jq -> don't get in the way. (CI asserts jq exists so the test matrix
# for this hook can't pass vacuously.)
command -v jq >/dev/null 2>&1 || { printf '{}'; exit 0; }

neutral() { printf '{}'; exit 0; }

tool=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null) || neutral
[ -z "$tool" ] && neutral

log() {
  [ -d "$HOME/.claude" ] || return 0
  echo "$(date +%H:%M:%S) hook=$0 tool=$tool -> $1" >> "$HOME/.claude/label-gate.log" 2>/dev/null
  return 0
}
allow() { log "ALLOW${1:+ ($1)}"; printf '{}'; exit 0; }
deny() {
  log "DENY: $1"
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# --- per-repo opt-out ------------------------------------------------------
# Walks up from the session cwd looking for .github/claude-labels.yml and reads
# exactly one line out of it. No YAML parser, no network, no subprocess per level.
cwd=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"
dir="$cwd"
while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
  if [ -f "$dir/.github/claude-labels.yml" ]; then
    grep -Eq '^enforce:[[:space:]]*false' "$dir/.github/claude-labels.yml" && neutral
    break
  fi
  dir=$(dirname "$dir")
done

# --- MCP create_issue ------------------------------------------------------
# tool_input is {owner, repo, title, body, assignees, labels, milestone}.
# One expression covers a missing key, null, and [] alike.
case "$tool" in
  mcp__*__create_issue)
    if echo "$input" | jq -e '(.tool_input.labels // []) | length > 0' >/dev/null 2>&1; then
      allow "mcp labelled"
    fi
    deny "Issue labelling: create_issue needs a non-empty \`labels\` array with exactly one type label (bug, enhancement, documentation, question, technical-debt, chore, test-gap, flaky-test, ci-failure) and optional area: labels. See the issue-labeller skill."
    ;;
  Bash) ;;
  *) neutral ;;
esac

# --- Bash --------------------------------------------------------------------
cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$cmd" ] && neutral

# Per-call escape hatch. One-shot, visible in the transcript, and the anchored
# regex below already tolerates the VAR=value prefix form.
case "$cmd" in *CLAUDE_LABELS_SKIP=1*) allow "skip requested" ;; esac

# Strip heredoc BODIES, then split what survives into segments.
#
# Stripping runs first and is the whole false-positive defence: an issue body
# that quotes `gh issue create` or `--label foo` must not be mistaken for the
# command itself. The opening line is kept so `--body-file - <<'EOF'` is still
# inspected. This is the same class of bug that was fixed in
# ~/.claude/hooks/suggest-compact-after-pr.sh, which is where the anchored
# regex below comes from.
_q="'"; _dq='"'
segments=$(printf '%s\n' "$cmd" | awk \
  -v opener="<<-?[ \\t]*[${_q}${_dq}]?[A-Za-z_][A-Za-z0-9_]*[${_q}${_dq}]?" \
  -v quotes="[${_q}${_dq}]" '
  function emit(s,   n, i, p) {
    n = split(s, p, /&&|\|\||;|\|/)
    for (i = 1; i <= n; i++) print p[i]
  }
  {
    if (ind != "") {
      l = $0; sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l)
      if (l == ind) ind = ""
      next
    }
    emit($0)
    if (match($0, opener)) {
      d = substr($0, RSTART, RLENGTH)
      sub(/^<<-?[ \t]*/, "", d)
      gsub(quotes, "", d)
      ind = d
    }
  }')

# An optional `VAR=value ` prefix run, then the exact subcommand, anchored at
# the start of a segment. Without the anchor, merely mentioning the phrase in a
# string triggers the gate; without the prefix group, `GH_TOKEN=x gh ...` evades it.
env_prefix='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
create_re="${env_prefix}gh[[:space:]]+issue[[:space:]]+create([[:space:]]|\$)"
label_cli_re="${env_prefix}gh[[:space:]]+label[[:space:]]+(create|delete|edit)([[:space:]]|\$)"
gh_api_re="${env_prefix}gh[[:space:]]+api([[:space:]]|\$)"
write_method_re='(^|[[:space:]])(-X|--method)[[:space:]]+(POST|PATCH|PUT|DELETE)([[:space:]]|$)'
help_re='(^|[[:space:]])(--help|-h|--web)([[:space:]]|$)'
# Empty quoted values are collapsed away before this runs, so `--label ""`
# leaves nothing for the value class to match and correctly reads as unlabelled.
has_label_re='(^|[[:space:]])(--label[[:space:]]+[^-[:space:]][^[:space:]]*|--label=[^[:space:]]+|-l[[:space:]]+[^-[:space:]][^[:space:]]*)'

approval_token="${TMPDIR:-/tmp}/.claude-label-canon-approved"
token_fresh() {
  [ -f "$approval_token" ] || return 1
  local mtime now
  mtime=$(stat -c %Y "$approval_token" 2>/dev/null || stat -f %m "$approval_token" 2>/dev/null) || return 1
  now=$(date +%s)
  [ $(( now - mtime )) -lt 1800 ]
}

CANON_HINT="Run the issue-labeller skill — it presents the taxonomy diff for approval and then unlocks this for 30 minutes."

while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  # Collapse empty quoted values so `--label ""` reads as no value.
  seg=${seg//\"\"/}
  seg=${seg//\'\'/}

  # --- taxonomy growth gate ---
  if [[ "$seg" =~ $label_cli_re ]] && ! token_fresh; then
    deny "Issue labelling: creating, editing or deleting labels needs approval first. $CANON_HINT"
  fi
  if [[ "$seg" =~ $gh_api_re ]]; then
    # REST: the hole that Bash(gh api *) leaves open, since it is allowed
    # unprompted while `gh label create` prompts.
    if [[ "$seg" == */labels* ]] && [[ "$seg" =~ $write_method_re ]] && ! token_fresh; then
      deny "Issue labelling: that gh api call writes to the repo's label set, which needs approval first. $CANON_HINT"
    fi
    if [[ "$seg" == *graphql* ]] && [[ "$seg" =~ (createLabel|updateLabel|deleteLabel) ]] && ! token_fresh; then
      deny "Issue labelling: that GraphQL mutation writes to the repo's label set, which needs approval first. $CANON_HINT"
    fi
  fi

  # --- issue must be labelled gate ---
  if [[ "$seg" =~ $create_re ]]; then
    [[ "$seg" =~ $help_re ]] && continue
    [[ "$seg" =~ $has_label_re ]] && continue
    deny "Issue labelling: \`gh issue create\` needs exactly one type label — bug, enhancement, documentation, question, technical-debt, chore, test-gap, flaky-test, or ci-failure — plus optional area: labels. Re-run with --label <type>. Genuinely need an unlabelled issue? Prefix the command with CLAUDE_LABELS_SKIP=1."
  fi
done <<< "$segments"

allow
