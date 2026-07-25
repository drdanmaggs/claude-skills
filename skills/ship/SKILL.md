---
name: ship
description: End-to-end pre-PR workflow. Commits uncommitted changes, verifies lint/types, runs multi-agent code review, auto-fixes issues, verifies full CI suite, and creates a draft PR. Use when work is done locally and you want to ship it cleanly. Invoke with /ship.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(bun:*), Bash(pnpm:*), Bash(npm:*), Bash(yarn:*), Bash(npx:*), Read, Grep, Glob, Task, Skill
---

# Ship

End-to-end workflow from local changes to draft PR. Chains: git hygiene → build verification → code review → fix loop → CI verification → PR creation.

After each stage, report briefly what happened before proceeding.

## Stage 0: Git Hygiene

Run in parallel:
```bash
git branch --show-current
git status --short
git log origin/main..HEAD --oneline
```

**Branch check:** If on `main` or `master`, infer a branch name from the staged/uncommitted changes and recent commit messages. Use conventional branch naming (`feat/`, `fix/`, `chore/`, `refactor/`, `docs/`) with a short kebab-case description. Create and switch to it without asking:
```bash
git checkout -b <inferred-branch-name>
```

**Uncommitted changes:** If the working tree is dirty (modified/untracked files excluding `.env*`, `node_modules`, lock files):
1. Analyse the changes and determine the conventional commit type, scope, and summary (follow `commit-discipline.md` — separate structural from behavioural, one logical unit per commit)
2. Stage relevant files explicitly (never `git add -A` blindly — skip `.env`, `.env.*`, credentials, binaries)
3. Commit using a conventional message

Report: "Committed X files (`<message>`)" — or "Branch already clean."

## Stage 1: Fast-fail Checks

Detect package manager from lockfile:
- `bun.lockb` → `bun`
- `pnpm-lock.yaml` → `pnpm`
- `yarn.lock` → `yarn`
- Otherwise → `npm`

Run both checks in parallel:
```bash
{pm} run lint
{pm} run type-check
```

**If ANY check fails → stop immediately.** Report which command failed with the error output. Do not attempt auto-fixes — lint/type failures indicate structural problems requiring manual resolution. Ask the user to fix and re-run `/ship`.

Note: `build` is intentionally excluded — it's not in CI (Vercel runs it on deployment), and it's slow. This gate exists to fail fast before the expensive code review in Stage 2.

Report: "Lint and typecheck passed." — or stop with the failure.

## Stage 2: Code Review (fresh context)

**Docs-only check:** If ALL committed changes are `*.md`, `*.mdx`, `*.txt`, `*.yml`, `*.yaml`, `*.json` (excluding `package.json`) → skip to Stage 2 Auto-merge.

Call `Skill("code-reviewer")`.

The code-reviewer spawns 4 parallel subagents (Bug Hunter, Standards Checker, Context Reviewer, Performance Reviewer) using the full branch diff (`git diff origin/main...HEAD`). This gives genuine fresh-eyes review at GitHub's scope.

Collect findings and categorise:
- **Must Fix** — bugs, security issues, type errors
- **Should Address** — CLAUDE.md violations
- **Suggestions** — optional improvements

Report: "Code review: N issues (M must-fix, K should-address, J suggestions)." — or "Code review: clean."

## Stage 2 Auto-merge (docs-only fast path)

Push, create PR, mark ready, and squash merge in one flow:
```bash
git push -u origin HEAD
gh pr create --title "<type>: <summary>" --body "<brief description>"
gh pr merge --squash --delete-branch
```

Report: "Docs-only: auto-merged." and stop.

## Stage 3: Fix Review Issues

If no Must Fix or Should Address findings → **immediately proceed to Stage 4. Do not stop.**

Report the finding count as a single line ("Stage 3: N issues to fix (M must-fix, K should-address)") then **immediately begin fixing — do not stop or wait for user input.**

For each finding, create a task:
```
TaskCreate: subject="Fix: <brief description>", activeForm="Fixing: <brief description>"
```

Then fix autonomously using the /tdd skill.

1. Mark task `in_progress`
2. Work through **Must Fix** items first, then **Should Address**
3. Follow Tidy First: structural commits (renames, extractions) before behavioural commits (logic changes)
4. One logical change per commit with a conventional commit message
5. Mark task `completed`
6. Skip **Suggestions** unless the fix is a single line

**If a finding requires architectural decisions** (multiple valid approaches, touches >3 files, unclear scope) → enter plan mode for that finding only, then resume.

After all fixes, re-run `Skill("code-reviewer")` to confirm issues are resolved.

**Max 2 review iterations.** If Must Fix or Should Address findings remain after 2 passes, surface them to the user and stop — do not create a PR with unresolved issues.

Report: "Fixed N issues across M commits, review re-passed." — or "Stage 3 complete — no issues to fix."

## Stage 4: Create Draft PR

Push the branch for the first time now that all checks have passed:
```bash
git push -u origin HEAD
```

Call `Skill("create-pr")`.

When providing context for the PR body, include:
- A concise summary of the work done on this branch
- If any issues were auto-fixed during stages 2–3, list them explicitly under an **"Auto-fixes applied during ship"** section so reviewers know what changed

The PR must be created as a draft (`--draft` flag).

Report: PR URL.

## Stage 5: PR Quality Gate

Immediately after Stage 4, invoke:

```
Skill("pr-quality")
```

This hands off to the autonomous review loop — no user input required. `pr-quality` will wait for the external CI code review, process it, fix all actionable issues, undraft the PR when clean, and poll CI until all checks pass. It will announce "READY TO MERGE" when done.

Do not wait or report anything before invoking. The handoff is seamless.

## Communication Style

Be concise. Report stage outcomes as single lines. Only expand when a stage fails or needs user input.

```
Stage 0: Committed 3 files (feat: add meal search)
Stage 1: Lint and typecheck passed
Stage 2: Code review: 2 issues (1 must-fix, 1 should-address)
Stage 3: Fixed 2 issues (null check + CLAUDE.md violation), review re-passed
Stage 4: https://github.com/owner/repo/pull/42 (draft)
Stage 5: → handing off to pr-quality
```

Clean path (no review issues):
```
Stage 0: Branch already clean.
Stage 1: Lint and typecheck passed.
Stage 2: Code review: clean.
Stage 3: No issues to fix — proceeding.
Stage 4: https://github.com/owner/repo/pull/42 (draft)
Stage 5: → handing off to pr-quality
```
