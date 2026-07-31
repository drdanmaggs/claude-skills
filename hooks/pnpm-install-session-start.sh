#!/usr/bin/env bash
# SessionStart hook: keep node_modules in step with pnpm-lock.yaml.
#
# WHY THIS EXISTS
# Nothing else reconciles an install to the lockfile. Dependabot advances
# pnpm-lock.yaml; git checkout/pull updates that file on disk; but node_modules
# is only ever rewritten by an explicit `pnpm install`. Every git worktree has
# its own node_modules, so installing in one does nothing for the others.
#
# Observed 2026-07-31 in Productivity_Coach: 2 of 7 worktrees were running a
# prettier two minor versions behind the lockfile. Files formatted there came
# out in a style CI then rejected.
#
# HISTORY
# This hook used to be registered in ~/.claude/settings.json. It was silently
# dropped on 2026-07-05 by a commit that resynced that repo wholesale to its
# working tree ("sync global config repo to dev-box state") — the script file
# survived, its registration did not, and nobody noticed for 26 days. It lives
# in the plugin now so it is versioned, tested, and uses ${CLAUDE_PLUGIN_ROOT}
# rather than a hardcoded $HOME path (a hardcoded path is what made the
# Mac -> Linux migration a rewrite-everything job in the first place).
#
# CONTRACT
# Never fail a session. Every path exits 0, including a failed install — a
# broken install should surface when a command actually needs it, not as an
# unexplained error at session start.
set -uo pipefail

# Local developer convenience only. Mirrors the guard on Productivity_Coach's
# post-checkout hook: self-hosted runners can carry hook config into a workflow
# step, and family-meal-planner-v3 hit exactly this — an unpinned install
# during checkout failed the job before a single check had run.
if [ -n "${CI:-}" ]; then
  exit 0
fi

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0

[ -n "$cwd" ] || exit 0
[ -d "$cwd" ] || exit 0
[ -f "$cwd/pnpm-lock.yaml" ] || exit 0

cd "$cwd" || exit 0

# pnpm rewrites node_modules/.modules.yaml on every install, so its mtime is
# the install time. If it is at least as new as the lockfile, we are current.
stamp='node_modules/.modules.yaml'

if [ -f "$stamp" ]; then
  if [ ! pnpm-lock.yaml -nt "$stamp" ]; then
    exit 0
  fi
  reason='pnpm-lock.yaml is newer than the last install'
else
  reason='node_modules is missing or was never installed by pnpm'
fi

echo "pnpm-install-session-start: ${reason} — running pnpm install --frozen-lockfile in ${cwd}"

if pnpm install --frozen-lockfile 2>&1 | tail -20; then
  echo 'pnpm-install-session-start: node_modules is now in step with the lockfile'
else
  echo 'pnpm-install-session-start: install did not complete cleanly — run pnpm install yourself before trusting local tooling' >&2
fi

exit 0
