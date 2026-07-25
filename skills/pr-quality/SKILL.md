---
name: pr-quality
description: >
  Autonomous end-to-end PR quality gate. Waits for and processes Claude code
  reviews in a loop, fixing all actionable issues and pushing after each round.
  Once reviews are clean, undrafts the PR and loops on CI until all checks pass.
  Routes test failures via /skip-failed-test (1-3) or /test-fixer (4+).
  Announces "READY TO MERGE" in ASCII art. Zero user interruption.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(pnpm:*), Read, Grep, Glob, Task, Skill
---

# PR Quality Gate

Autonomous fix-verify-push cycle. Waits for external code reviews, processes
them, fixes all actionable issues, then undrafts and waits for CI to pass.
Zero user interruption except ambiguous merge conflicts.

## Delegation Rules (CRITICAL)

### Test Failures → Route by count

Never fix test failures yourself.

**1-3 failures:** Invoke `/skip-failed-test` per failing test file.
- Analyses whether the failure is related to this PR
- If unrelated → skips + creates documented GitHub issue
- If related → routes internally to `/test-fixer`

**4+ failures:** Invoke `/test-fixer` directly (likely systemic — PR broke shared code or main is broken).

### Review-Flagged Bugs → ALWAYS delegate to /tdd (bug-fix mode)

**Never fix review-identified bugs yourself with a reactive patch.**

Invoke `/tdd` and pass it:
- The specific bug description from the review comment
- The failing scenario (what action triggers the bug)
- The relevant file paths

Why: Fixing without a failing test first creates dependency on the next
review cycle for correctness validation. Each uncertain patch extends the
review loop. /tdd's RED→GREEN proves the fix is correct locally before push.

---

## Workflow

### Stage 0: Initialise

Run in parallel:
```bash
git branch --show-current
git status --short
git log origin/main..HEAD --oneline
gh pr view --json number,isDraft,state,reviews,statusCheckRollup,mergeable,mergeStateStatus
```

Capture:
- `PR_NUMBER` — used for all subsequent `gh pr` commands
- `isDraft` — determines whether Stage 3 (undraft) is needed
- `mergeStateStatus` / `mergeable` — conflict detection
- Current review list and CI status as baseline

Categorise:
- `mergeStateStatus == DIRTY` or `mergeable == CONFLICTING` → handle in Stage 1
- Local `git status` shows conflict markers → handle in Stage 1
- Everything else → enter Stage 2 (Review Loop)

---

### Stage 1: Resolve Conflicts

If conflicts exist, rebase:
```bash
git fetch origin main
git rebase origin/main
```

Resolve conflicts preserving intent of both branches. If resolution is genuinely ambiguous, stop and ask the user (this is the
ONLY permitted interruption in the entire skill).

Once the user provides guidance, continue with the rebase using their guidance.

---

### Stage 2: Review Loop

**This is an infinite loop. Run without stopping until the exit condition is met.**

Each iteration:

**Step 1 — Sync with main**

```bash
git fetch origin main
git rebase origin/main
```

If rebase has conflicts, resolve them (same rules as Stage 1) before continuing.
This must run at the start of every iteration — another PR may have merged to
main since the last push, which would leave this branch conflicting and cause
GitHub Actions to silently refuse to queue runs.

**Step 2 — Verify locally**
```bash
pnpm lint && pnpm type-check && pnpm vitest run
```
All must pass before pushing. If they fail, fix first (delegation rules: 1-3 test failures → `/skip-failed-test` per file, 4+ → `/test-fixer`),
then re-verify.

**Step 3 — Push**
```bash
git push origin HEAD
```
If nothing to push (remote already up to date), skip push but still enter
Step 3 — a review may already be waiting.

Record `PUSH_TIME` immediately after push (or current time if skipped):
```bash
PUSH_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

**Step 4 — Wait for review**

Poll every 30 seconds until a code review appears on the PR submitted at or
after `PUSH_TIME`:
```bash
gh pr view $PR_NUMBER --json reviews,comments
```

Look for any new review (formal PR review) or comment submitted with
`submittedAt >= PUSH_TIME`. No timeout — wait indefinitely. Do not ask the
user for input.

On the very first iteration only: also accept any existing unprocessed review
submitted before `PUSH_TIME` if no newer one appears within the first poll.

**Step 4 — Process review**

Read the review content and apply the YAGNI filter:

**Implement (high signal):**
- Bugs — correctness issues with concrete impact
- Security / data-loss risks
- CLAUDE.md violations
- Missing tests for shipped behaviour

**Defer (low signal → create GitHub issue instead):**
- "Could be more extensible"
- "Consider adding X for future use"
- Performance speculation without profiling data
- Style preferences outside project standards

For each **bug** → delegate to `/tdd` (bug-fix mode)
For each **test failure** → delegate to `/test-fixer`
For each **type / lint / build error** → fix directly
For **refactor / improvement** → implement if simple, defer if speculative

**Step 5 — Post decision log**

Post a top-level PR comment summarising decisions:
```bash
gh pr comment $PR_NUMBER --body "Review response complete.

**Implemented:**
- [item]: [brief reason — e.g. correctness bug, CLAUDE.md violation]

**Skipped (with reasons):**
- [item]: [YAGNI / speculative / not this PR's scope]

**Test failures handled:**
- [Fixed / skipped with issue #X]"
```

For each inline review comment that was acted on or deferred, reply in its thread:
```bash
# Implemented item
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -f body="Fixed in [commit hash]. [One sentence on what changed and why.]"

# Deferred item
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -f body="Skipping — [reason, e.g. speculative, unused code, out of scope]. [Issue #X created if appropriate.]"
```

Omit sections that don't apply (e.g. no skipped items → omit that block).

**Step 6 — Branch on outcome**
- If actionable items were fixed → go back to Step 1 (next iteration, sync with main first)
- **Exit condition:** review has no actionable items after YAGNI filtering
  → proceed to Stage 3

---

### Stage 3: Undraft

**Run once.** Skip if PR was already non-draft at Stage 0.

```bash
gh pr ready
```

This converts the PR to non-draft and triggers CI.

---

### Stage 4: CI Loop

**This is an infinite loop. Run without stopping until all checks pass.**

Each iteration:

**Step 1 — Poll CI**
```bash
gh pr view $PR_NUMBER --json statusCheckRollup,mergeable,mergeStateStatus
```
Check every 30 seconds. If any checks are still `PENDING` or `IN_PROGRESS`,
keep polling.

**Step 1a — Stuck detection (CRITICAL)**

Before continuing to poll, check for merge conflicts blocking CI:

```bash
gh pr view $PR_NUMBER --json mergeable,mergeStateStatus
```

If `mergeStateStatus` is `DIRTY` or `mergeable` is `CONFLICTING`:
- **This is why CI is stuck** — GitHub Actions will not run on a conflicting branch
- Immediately jump back to **Stage 1** (Resolve Conflicts) and rebase
- Do NOT continue polling

If checks have been exclusively `PENDING`/`QUEUED` (no runs have started) for
more than 5 minutes, **always** run this conflict check — stuck queues with zero
runs executing are the canonical symptom of an unresolved merge conflict.

**Step 2 — Branch on outcome**
- **All checks pass** → exit loop → proceed to Finale
- **Any check fails** → diagnose and fix:
  - Test failure (1-3) → `/skip-failed-test` per failing test file
  - Test failure (4+) → `/test-fixer` (systemic issue)
  - Type error → fix directly
  - Lint error → fix directly
  - Build error → fix directly (or stop and report if root cause is unclear)

  After fixing: verify locally (`pnpm lint && pnpm type-check && pnpm vitest run`),
  push, then go back to Step 1. **Do NOT wait for a code review in this phase.**

---

### Finale: Ready to Merge

Output a summary report followed by ASCII art:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ██████╗ ███████╗ █████╗ ██████╗ ██╗   ██╗
  ██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
  ██████╔╝█████╗  ███████║██║  ██║ ╚████╔╝
  ██╔══██╗██╔══╝  ██╔══██║██║  ██║  ╚██╔╝
  ██║  ██║███████╗██║  ██║██████╔╝   ██║
  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝    ╚═╝

  ████████╗ ██████╗
  ╚══██╔══╝██╔═══██╗
     ██║   ██║   ██║
     ██║   ██║   ██║
     ██║   ╚██████╔╝
     ╚═╝    ╚═════╝

  ███╗   ███╗███████╗██████╗  ██████╗ ███████╗
  ████╗ ████║██╔════╝██╔══██╗██╔════╝ ██╔════╝
  ██╔████╔██║█████╗  ██████╔╝██║  ███╗█████╗
  ██║╚██╔╝██║██╔══╝  ██╔══██╗██║   ██║██╔══╝
  ██║ ╚═╝ ██║███████╗██║  ██║╚██████╔╝███████╗
  ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then list:
- PR URL
- Review rounds completed
- Issues fixed (with delegation method used)
- Issues deferred (with GitHub issue links)
