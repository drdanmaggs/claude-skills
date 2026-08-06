#!/usr/bin/env bash
# handoff-gate.sh — PreToolUse (Skill) gate that keeps skill handoffs cold.
# Shipped by the claude-skills plugin; registered via hooks/hooks.json.
#
# WHY THIS IS A HOOK AND NOT A SENTENCE IN A SKILL
# ------------------------------------------------
# /issue-scope, /tdd and /ship used to chain inside one session because their own
# instructions told them to. Measured across 484 sessions: /tdd alone peaks at a
# 131k mean context, tdd+ship at 297k, issue-scope+tdd+ship at 537k. Context rot
# degrades output quality with ABSOLUTE input length long before the window fills,
# so those tokens are actively harmful, not merely expensive.
#
# The skills now stop and tell the user to /clear. But prose degrades silently —
# that is the documented lesson behind /ship's review artefact, where a review
# went from six agents to none across one PR series while every local gate still
# reported success. Per ~/.claude/CLAUDE.md: "prefer a mechanism you cannot
# silently skip over an instruction you can." This is the mechanism.
#
# THE SIGNAL
# ----------
# `.tdd-session.md` exists  <=>  a /tdd session is live in this repo.
# /tdd writes it at Stage 0 and deletes it at Completion, immediately before it
# stops. So a Skill(ship) arriving while it exists is a mid-session chain, and a
# Skill(ship) arriving after teardown is a fresh session doing the right thing.
# The teardown-before-stop ordering in skills/tdd/SKILL.md is what makes this
# reliable; do not reorder it.
#
# THE PAYLOAD (verified empirically, not guessed)
# -----------------------------------------------
# The Skill tool presents:
#   {"tool_name":"Skill","tool_input":{"skill":"claude-skills:ship","args":"..."}}
# Names may be plugin-scoped ("claude-skills:tdd") or bare ("worktree-reset"),
# so we compare on the segment after the last colon. Confirmed against real
# tool_use records in ~/.claude/projects/*/*.jsonl.
#
# ESCAPABLE BY DESIGN
# -------------------
# The denial names its own bypass (`rm .tdd-session.md`). A gate you cannot get
# past when it is wrong is a gate people route around permanently.
#
# Logs every active invocation to ~/.claude/handoff-gate.log, including hook=$0,
# so a stale plugin-cache copy is identifiable from the log alone.

input=$(cat)

# No jq -> don't get in the way.
command -v jq >/dev/null 2>&1 || { printf '{}'; exit 0; }

neutral() { printf '{}'; exit 0; }

tool=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null) || neutral
[ "$tool" = "Skill" ] || neutral

raw=$(echo "$input" | jq -r '.tool_input.skill // ""' 2>/dev/null) || neutral
[ -n "$raw" ] || neutral

# "claude-skills:ship" -> "ship";  "ship" -> "ship"
skill="${raw##*:}"

case "$skill" in
  tdd|ship|pr-quality) ;;
  *) neutral ;;
esac

cwd=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null) || neutral
if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then neutral; fi

# Walk up from cwd to find the repo's .tdd-session.md.
dir="$cwd"; session_file=""
while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
  if [ -f "$dir/.tdd-session.md" ]; then session_file="$dir/.tdd-session.md"; break; fi
  dir=$(dirname "$dir")
done
[ -n "$session_file" ] || neutral          # no live TDD session -> allow

log() {
  echo "$(date +%H:%M:%S) hook=$0 skill=$raw session=$session_file -> $1" \
    >> "$HOME/.claude/handoff-gate.log" 2>/dev/null || true
}

reason="A /tdd session is live in this repo (${session_file} exists), so invoking /${skill} now would chain it into the same context. That is the 537k-token path this gate exists to stop. Finish the TDD session so it tears down its state and stops, then run /clear and /${skill} in a fresh session. If this file is stale, delete it: rm ${session_file}"

log "DENY /$skill"
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' \
  "$(printf '%s' "$reason" | jq -Rs .)"
exit 0
