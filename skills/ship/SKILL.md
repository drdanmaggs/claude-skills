---
name: ship
description: End-to-end pre-PR workflow. Commits uncommitted changes, verifies lint/types, creates the PR, and babysits CI until green. Code review runs in CI, not here. Use when work is done locally and you want to ship it cleanly. Invoke with /ship.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(bun:*), Bash(pnpm:*), Bash(npm:*), Bash(yarn:*), Bash(npx:*), Read, Grep, Glob, Task, Skill
---

# Ship

End-to-end workflow from local changes to a PR under CI review. Chains: git hygiene → build verification → PR creation → CI babysitting. Code review is deliberately NOT here — see below.

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

Note: `build` is intentionally excluded — it's not in CI (Vercel runs it on deployment), and it's slow. This gate exists to fail fast locally, before spending a CI run and a review on something that cannot compile.

Report: "Lint and typecheck passed." — or stop with the failure.

## Code review is CI's job, not this skill's

`/ship` deliberately does **not** run a code review. It used to, and the review
was good — but where it ran made it unreliable in a way that had nothing to do
with its quality:

- Whether it ran, and with how many agents, was visible only inside the Claude
  Code session. Nothing downstream could observe it.
- So it degraded silently. Across one recent PR series it went from six agents to
  three to two to not being invoked at all, while every local gate still reported
  success — because those gates recorded a *claim* that a review happened rather
  than the review itself.
- The person who decides to merge is looking at the PR, not at a terminal that
  scrolled past hours ago. A review they never see cannot inform that decision.

So the review belongs on the PR, in CI, where it always runs and leaves a durable
artefact. Both repos using this skill have `claude-code-review.yml` for exactly
that. **Do not reintroduce a review step here** — a second review that sometimes
runs is worse than one that always does, because it invites treating the
sometimes one as sufficient.

If you want fast feedback *before* pushing on something genuinely risky, invoke
`Skill("code-reviewer")` explicitly. That is a deliberate act for a specific
change, which is a different thing from a pipeline stage that is supposed to
happen every time and quietly stops.

## Docs-only fast path

If ALL committed changes are `*.md`, `*.mdx`, `*.txt`, `*.yml`, `*.yaml`, `*.json`
(excluding `package.json`), push, create the PR, and squash merge in one flow:

```bash
git push -u origin HEAD
gh pr create --title "<type>: <summary>" --body "<brief description>"
gh pr merge --squash --delete-branch
```

Report: "Docs-only: auto-merged." and stop.

## Stage 2: Create the PR

Push the branch now that lint and type-check have passed:
```bash
git push -u origin HEAD
```

Call `Skill("create-pr")`.

When providing context for the PR body, include a concise summary of the work
done on this branch. The CI review will post its own findings separately — do not
pre-empt or summarise them, since at PR-creation time they do not exist yet.

The PR must be created as a draft (`--draft` flag).

Report: PR URL.

## Stage 3: PR Quality Gate

Immediately after Stage 2, invoke:

```
Skill("pr-quality")
```

This hands off to the autonomous loop — no user input required. `pr-quality` waits for the CI code review, processes it, fixes all actionable issues, undrafts the PR when clean, and polls CI until every check passes. It announces "READY TO MERGE" when done.

Invoke the skill rather than hand-rolling the polling and printing the banner yourself. A hand-rolled finale is indistinguishable from a real one, which makes it impossible to tell afterwards which stages actually ran — the same failure that removed the review stage above.

Do not wait or report anything before invoking. The handoff is seamless.

## Communication Style

Be concise. Report stage outcomes as single lines. Only expand when a stage fails or needs user input.

```
Stage 0: Committed 3 files (feat: add meal search)
Stage 1: Lint and typecheck passed
Stage 2: https://github.com/owner/repo/pull/42
Stage 3: → handing off to pr-quality (CI review + checks)
```

