---
name: ship
description: End-to-end pre-PR workflow. Commits uncommitted changes, verifies lint/types, runs a full local multi-agent code review, creates the PR, posts the review to it, and babysits CI until green. Use when work is done locally and you want to ship it cleanly. Invoke with /ship.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(bun:*), Bash(pnpm:*), Bash(npm:*), Bash(yarn:*), Bash(npx:*), Read, Grep, Glob, Task, Skill
---

# Ship

End-to-end workflow from local changes to a PR under CI review. Chains: git hygiene → build verification → full local review → PR creation → post the review to the PR → CI babysitting.

The review runs here **and** in CI, and it posts its result to the PR. That last
part is not decoration — see "Why the local review posts to the PR" below before
changing anything about Stage 2 or Stage 4.

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

## Docs-only fast path

Evaluate this **before** Stage 2 — there is no point running six agents over a
branch with no code in it.

If ALL committed changes are `*.md`, `*.mdx`, `*.txt`, `*.yml`, `*.yaml`, `*.json`
(excluding `package.json`), push, create the PR, and squash merge in one flow:

```bash
git push -u origin HEAD
gh pr create --title "<type>: <summary>" --body "<brief description>"
gh pr merge --squash --delete-branch
```

Report: "Docs-only: auto-merged." and stop.

This is the one path that ships without a review artefact, and it can only be
taken when there is nothing reviewable. Do not widen it. `*.yml` in that list is
already generous — a workflow change is code.

## Stage 2: Full Local Review

Invoke:

```
Skill("code-reviewer")
```

in **`full` mode** — all six agents over the whole branch diff. Not a subset, not
a sample. This is the branch's first review and the only one that sees it whole;
every later round is scoped against this one.

The review auto-fixes what it can, so those commits land *before* the PR exists
and the PR opens with them already in. **Hold the artefact it emits** — the block
beginning `<!-- local-review sha=... -->`. Stage 4 posts it.

If the review's circuit breaker trips (not converging after 3 loops), continue to
Stage 3 anyway. The artefact records the unresolved findings and the PR carries
them where they can be seen; stopping here would leave the work stranded locally
with no record at all.

**Do not stop here, and do not wait for the user.** Report the finding count as a
single line and keep going. `code-reviewer` owns the fix loop and its circuit
breaker — do not re-implement a second fix loop in this skill. Two loops in two
places is how they drift apart, and the one that drifts is always the one nobody
is reading.

The exception is a finding needing an architectural decision (several valid
approaches, or scope that is genuinely the user's call). Raise that one finding,
then resume.

Report: "Review: 6 agents, N findings, N auto-fixed."

## Why the local review posts to the PR

This stage was **removed** on 28 Jul 2026 and is back only because the artefact
exists. The removal reasons were never about review quality — the review was good.
They were about observability, and all three still apply:

- Whether it ran, and with how many agents, was visible only inside the Claude
  Code session. Nothing downstream could observe it.
- So it degraded silently. Across one PR series it went from six agents to three
  to two to not being invoked at all, while every local gate still reported
  success — because those gates recorded a *claim* that a review happened rather
  than the review itself.
- The person who decides to merge is looking at the PR, not at a terminal that
  scrolled past hours ago. A review they never see cannot inform that decision.

Stage 4 answers all three: the artefact is durable next to the merge button, it
names its own agent count so a six-to-two reduction is visible and reasoned, and
CI asserts it exists for the head sha. Degradation stops being invisible and
becomes a red check.

Which is why:

- **The artefact IS the review, not a record that one happened.** Never substitute
  a marker file, a receipt, a `.review-passed` stamp, or a "review: clean" line.
  That distinction is the entire lesson of the removal — gates that recorded the
  claim are exactly what failed.
- **Never skip Stage 4 to save a step.** A review that ran and was not posted is,
  from the merge button's point of view, a review that did not happen.
- **CI's `claude-code-review.yml` still runs, and stays.** It is a second opinion
  with fresh context, and it is the only review a PR gets when it did not come
  through `/ship`. Two reviews is the intent, not redundancy to be optimised away.

## Stage 3: Create the PR

Push the branch now that lint, type-check and the review have passed:
```bash
git push -u origin HEAD
```

Call `Skill("create-pr")`.

When providing context for the PR body, include a concise summary of the work
done on this branch. Both reviews post their own findings separately — do not
pre-empt or summarise them in the body.

The PR must be created as a draft (`--draft` flag).

Report: PR URL.

## Stage 4: Post the Review Artefact

Post the block held from Stage 2, verbatim:

```bash
gh pr comment <PR_NUMBER> --body-file -
```

Use `--body-file -` and pipe the body in. Passing it via `--body` mangles the
`<!-- local-review ... -->` marker through shell quoting, and CI parses that
marker — a mangled one reads as no review at all.

Verify the comment landed (`gh pr view <PR> --json comments`) before continuing.
This is the step the whole design rests on; a silent failure here reproduces the
original problem exactly.

Report: "Review artefact posted."

## Stage 5: PR Quality Gate

Immediately after Stage 4, invoke:

```
Skill("pr-quality")
```

This hands off to the autonomous loop — no user input required. `pr-quality` runs an incremental local review before each push, waits for the CI code review, processes both, fixes all actionable issues, undrafts the PR when clean, and watches CI until every check passes. It announces "READY TO MERGE" when done.

Invoke the skill rather than hand-rolling the polling and printing the banner yourself. A hand-rolled finale is indistinguishable from a real one, which makes it impossible to tell afterwards which stages actually ran — the same failure that got the review stage removed above.

Do not wait or report anything before invoking. The handoff is seamless.

## Communication Style

Be concise. Report stage outcomes as single lines. Only expand when a stage fails or needs user input.

```
Stage 0: Committed 3 files (feat: add meal search)
Stage 1: Lint and typecheck passed
Stage 2: Review: 6 agents, 4 findings, 3 auto-fixed
Stage 3: https://github.com/owner/repo/pull/42
Stage 4: Review artefact posted
Stage 5: → handing off to pr-quality (CI review + checks)
```

