#!/usr/bin/env bash
# Offline test matrix for label-gate.sh — no Claude Code, no network, no gh.
# Pipes synthetic PreToolUse payloads at the hook and asserts allow/deny.
# Run: ./label-gate.test.sh   (resolves the hook next to this script)
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/label-gate.sh"
PASS=0; FAIL=0

T="$(mktemp -d)"
mkdir -p "$T/plain" "$T/optout/.github" "$T/optin/.github" "$T/optin/deep/nested"
mkdir -p "$T/optout/deep/nested"
trap 'rm -rf "$T"' EXIT

printf 'version: 1\nenforce: false\n' > "$T/optout/.github/claude-labels.yml"
printf 'version: 1\nenforce: true\n'  > "$T/optin/.github/claude-labels.yml"

TOKEN="$T/.claude-label-canon-approved"
grant_token()  { : > "$TOKEN"; }
expire_token() { : > "$TOKEN"; touch -d '40 minutes ago' "$TOKEN" 2>/dev/null || touch -t "$(date -v-40M +%Y%m%d%H%M 2>/dev/null)" "$TOKEN"; }
revoke_token() { rm -f "$TOKEN"; }

# Payload builders — jq does the JSON escaping so heredocs/newlines survive.
bash_payload() { # <command> [cwd]
  jq -nc --arg cmd "$1" --arg cwd "${2:-$T/plain}" \
    '{tool_name:"Bash",cwd:$cwd,hook_event_name:"PreToolUse",tool_input:{command:$cmd}}'
}
mcp_payload() { # <tool_name> <labels_json_or_omitted>
  if [ "$#" -ge 2 ]; then
    jq -nc --arg t "$1" --argjson l "$2" --arg cwd "$T/plain" \
      '{tool_name:$t,cwd:$cwd,hook_event_name:"PreToolUse",tool_input:{owner:"o",repo:"r",title:"t",body:"b",labels:$l}}'
  else
    jq -nc --arg t "$1" --arg cwd "$T/plain" \
      '{tool_name:$t,cwd:$cwd,hook_event_name:"PreToolUse",tool_input:{owner:"o",repo:"r",title:"t",body:"b"}}'
  fi
}

run_case() { # <desc> <ALLOW|DENY> <payload>
  local desc="$1" expect="$2" payload="$3" out decision
  out="$(printf '%s' "$payload" | TMPDIR="$T" "$HOOK" 2>/dev/null)"
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

echo "== gh issue create: label detection =="
run_case "bare create                  -> DENY"  DENY  "$(bash_payload 'gh issue create --title x --body y')"
run_case "--label bug                  -> ALLOW" ALLOW "$(bash_payload 'gh issue create --title x --label bug')"
run_case "-l bug                       -> ALLOW" ALLOW "$(bash_payload 'gh issue create --title x -l bug')"
run_case "--label=bug                  -> ALLOW" ALLOW "$(bash_payload 'gh issue create --title x --label=bug')"
run_case "repeated --label             -> ALLOW" ALLOW "$(bash_payload 'gh issue create --title x --label bug --label area:ci')"
run_case "--label with empty value     -> DENY"  DENY  "$(bash_payload 'gh issue create --title x --label ""')"
run_case "--label immediately -flag    -> DENY"  DENY  "$(bash_payload 'gh issue create --label --body y')"
run_case "--help                       -> ALLOW" ALLOW "$(bash_payload 'gh issue create --help')"
run_case "--web                        -> ALLOW" ALLOW "$(bash_payload 'gh issue create --web --title x')"

echo "== env-var prefix (the escape-hatch regex group) =="
run_case "GH_TOKEN=x, no label         -> DENY"  DENY  "$(bash_payload 'GH_TOKEN=x gh issue create --title y')"
run_case "GH_TOKEN=x, with label       -> ALLOW" ALLOW "$(bash_payload 'GH_TOKEN=x gh issue create --title y --label bug')"

echo "== chained commands =="
run_case "git status && create, no lbl -> DENY"  DENY  "$(bash_payload 'git status && gh issue create --title x')"
run_case "labelled; then unlabelled    -> DENY"  DENY  "$(bash_payload 'gh issue create --title a --label bug && gh issue create --title b')"
run_case "newline-separated, no label  -> DENY"  DENY  "$(bash_payload 'git status
gh issue create --title x')"
run_case "piped, no label              -> DENY"  DENY  "$(bash_payload 'cat body.md | gh issue create --title x --body-file -')"

echo "== heredoc bodies must not trigger false positives =="
run_case "body quotes 'gh issue create', real cmd labelled -> ALLOW" ALLOW "$(bash_payload 'gh issue create --title x --label bug --body-file - <<'"'"'EOF'"'"'
Claude ran gh issue create --title y without a label here.
EOF')"
run_case "body contains --label, real cmd has none         -> DENY"  DENY  "$(bash_payload 'gh issue create --title x --body-file - <<'"'"'EOF'"'"'
Suggested fix: pass --label technical-debt next time.
EOF')"
run_case "body contains 'Labels: bug', real cmd has none   -> DENY"  DENY  "$(bash_payload 'gh issue create --title x --body-file - <<'"'"'EOF'"'"'
Labels: bug, area:testing
EOF')"

echo "== unrelated commands stay untouched =="
run_case "echo mentioning the phrase   -> ALLOW" ALLOW "$(bash_payload 'echo "remember to run gh issue create later"')"
run_case "gh pr create                 -> ALLOW" ALLOW "$(bash_payload 'gh pr create --title x --body y')"
run_case "gh issue list --label        -> ALLOW" ALLOW "$(bash_payload 'gh issue list --label flaky-test --state open')"
run_case "gh issue edit --add-label    -> ALLOW" ALLOW "$(bash_payload 'gh issue edit 5 --add-label bug')"
run_case "gh issue comment             -> ALLOW" ALLOW "$(bash_payload 'gh issue comment 5 --body x')"

echo "== escape hatches =="
run_case "CLAUDE_LABELS_SKIP=1         -> ALLOW" ALLOW "$(bash_payload 'CLAUDE_LABELS_SKIP=1 gh issue create --title x')"
run_case "repo with enforce: false     -> ALLOW" ALLOW "$(bash_payload 'gh issue create --title x' "$T/optout/deep/nested")"
run_case "repo with enforce: true      -> DENY"  DENY  "$(bash_payload 'gh issue create --title x' "$T/optin/deep/nested")"
run_case "no config anywhere (default) -> DENY"  DENY  "$(bash_payload 'gh issue create --title x' "$T/plain")"

echo "== label creation gate: CLI =="
revoke_token
run_case "gh label create, no token    -> DENY"  DENY  "$(bash_payload 'gh label create foo --color ededed')"
run_case "gh label delete, no token    -> DENY"  DENY  "$(bash_payload 'gh label delete foo --yes')"
run_case "gh label edit, no token      -> DENY"  DENY  "$(bash_payload 'gh label edit foo --name bar')"
run_case "gh label list                -> ALLOW" ALLOW "$(bash_payload 'gh label list --limit 100')"
grant_token
run_case "gh label create, fresh token -> ALLOW" ALLOW "$(bash_payload 'gh label create foo --color ededed')"
expire_token
run_case "gh label create, stale token -> DENY"  DENY  "$(bash_payload 'gh label create foo --color ededed')"
revoke_token

echo "== label creation gate: REST (the gh api hole) =="
run_case "api --method POST /labels    -> DENY"  DENY  "$(bash_payload 'gh api --method POST /repos/o/r/labels -f name=foo -f color=ededed')"
run_case "api -X POST repos/../labels  -> DENY"  DENY  "$(bash_payload 'gh api -X POST repos/o/r/labels -f name=foo')"
run_case "api PATCH rename label       -> DENY"  DENY  "$(bash_payload 'gh api --method PATCH /repos/o/r/labels/old -f new_name=new')"
run_case "api DELETE label             -> DENY"  DENY  "$(bash_payload 'gh api -X DELETE /repos/o/r/labels/old')"
run_case "api GET /labels              -> ALLOW" ALLOW "$(bash_payload 'gh api /repos/o/r/labels --paginate')"
run_case "api POST elsewhere           -> ALLOW" ALLOW "$(bash_payload 'gh api --method POST /repos/o/r/issues/1/comments -f body=hi')"

echo "== label creation gate: GraphQL =="
run_case "graphql createLabel          -> DENY"  DENY  "$(bash_payload 'gh api graphql -f query='"'"'mutation { createLabel(input:{name:"x"}) { label { id } } }'"'"'')"
run_case "graphql addSubIssue          -> ALLOW" ALLOW "$(bash_payload 'gh api graphql -f query='"'"'mutation { addSubIssue(input:{issueId:"a",subIssueId:"b"}) { issue { id } } }'"'"'')"

echo "== MCP create_issue =="
run_case "labels: []                   -> DENY"  DENY  "$(mcp_payload 'mcp__github__create_issue' '[]')"
run_case "labels key absent            -> DENY"  DENY  "$(mcp_payload 'mcp__github__create_issue')"
run_case "labels: null                 -> DENY"  DENY  "$(mcp_payload 'mcp__github__create_issue' 'null')"
run_case "labels: [\"bug\"]              -> ALLOW" ALLOW "$(mcp_payload 'mcp__github__create_issue' '["bug"]')"
run_case "renamed MCP server, no lbls  -> DENY"  DENY  "$(mcp_payload 'mcp__github-remote__create_issue')"

echo "== graceful degradation (never fail closed) =="
run_case "unrelated tool name          -> ALLOW" ALLOW '{"tool_name":"BashOutput","tool_input":{"bash_id":"1"}}'
run_case "malformed JSON               -> ALLOW" ALLOW 'not json at all'
run_case "no tool_input.command        -> ALLOW" ALLOW '{"tool_name":"Bash","tool_input":{}}'

# jq missing must be invisible, not vacuously green — the CI job asserts
# `jq --version` separately so this case can't hide a broken matrix.
mkdir -p "$T/nojq"
for b in bash env cat date grep sed awk touch stat; do
  p="$(command -v "$b" 2>/dev/null)" && ln -sf "$p" "$T/nojq/$b"
done
out="$(printf '%s' "$(bash_payload 'gh issue create --title x')" | PATH="$T/nojq" TMPDIR="$T" "$HOOK" 2>/dev/null)"
if echo "$out" | grep -q '"permissionDecision":"deny"'; then
  FAIL=$((FAIL+1)); printf '  ✗ %s — expected ALLOW got DENY\n' "jq unavailable            -> ALLOW"
else
  PASS=$((PASS+1)); printf '  ✓ %s\n' "jq unavailable               -> ALLOW"
fi

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
