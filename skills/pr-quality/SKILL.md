---
name: pr-quality
description: >
  Autonomous end-to-end PR quality gate. Runs an incremental local review before
  each push, then waits for and processes Claude code reviews in a loop, fixing
  all actionable issues and posting a review artefact with every push.
  Once reviews are clean, undrafts the PR and watches CI until all checks pass.
  Routes test failures via /skip-failed-test (1-3) or /test-fixer (4+).
  Announces "READY TO MERGE" in ASCII art. Zero user interruption.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(pnpm:*), Read, Grep, Glob, Task, Skill, Monitor, TaskStop
---

# PR Quality Gate

Autonomous review-fix-verify-push cycle. Reviews each round's delta locally,
waits for the CI review, processes both, fixes all actionable issues, then
undrafts and waits for CI to pass. Zero user interruption except ambiguous merge
conflicts.

**Waiting is done with the `Monitor` tool, never an inline poll loop.** Foreground
`sleep` is blocked in this harness, so "check every 30 seconds" written into the
conversation cannot execute as described. Every monitor's filter must match
failure states as well as success — a filter that only matches good news goes
silent on a crash, and silence is indistinguishable from still-waiting.

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

**Step 2b — Incremental local review**

Find the sha already reviewed, from the most recent review artefact on the PR:

```bash
LAST_REVIEWED=$(gh api --paginate --slurp "/repos/{owner}/{repo}/issues/$PR_NUMBER/comments?per_page=100" \
  | jq -r '[add[]? | .body | capture("<!-- local-review sha=(?<sha>[0-9a-f]{40})") .sha] | last // empty')
```

If `LAST_REVIEWED` equals `HEAD`, skip this step — nothing new to review.

Otherwise invoke `Skill("code-reviewer")` in **`incremental` mode** since
`LAST_REVIEWED`. It selects its own agents by tier and escalates back to all six
on its own rules — do not second-guess the selection or trim it further.

If no artefact is found at all, run **`full`** mode. An unknown starting point is
not a small delta; it is an unknown one.

Auto-fixes commit as part of the review. Then re-run Step 2 (the fixes must pass
lint/types/tests too) before pushing.

**Step 3 — Push, then post the artefact**
```bash
git push origin HEAD
```
If nothing to push (remote already up to date), skip push but still enter
Step 4 — a review may already be waiting.

Post the artefact from Step 2b, after the push so its sha matches what CI sees.
`code-reviewer` wrote it to **`.local-review.md`** at the repo root; post that
file, and check first that it reviews the sha you just pushed:

```bash
REVIEWED_SHA=$(sed -n 's/.*<!-- local-review sha=\([0-9a-f]\{40\}\).*/\1/p' .local-review.md | head -1)
if [ "$REVIEWED_SHA" != "$(git rev-parse HEAD)" ]; then
  echo "STALE: .local-review.md reviews ${REVIEWED_SHA:-<no marker>}, HEAD is $(git rev-parse HEAD)"
  exit 1
fi
gh pr comment "$PR_NUMBER" --body-file .local-review.md
```

The guard matters more here than anywhere: this loop rebases on every iteration,
so HEAD moves under the file. A mismatch means the review predates the rebase —
re-run Step 2b rather than posting it.

**Every push carries its own artefact.** CI asserts that the head sha has been
reviewed, so a push without one turns the PR red — correctly. Resist the urge to
batch several rounds into one comment: the artefact's job is to say *which sha*
was reviewed, and a comment covering three shas says it of none of them.

Record `PUSH_TIME` immediately after push (or current time if skipped):
```bash
PUSH_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

**Step 4 — Wait for the CI review**

Use the `Monitor` tool, not a polling loop in the conversation. Foreground `sleep`
is blocked, so a "check every 30 seconds" loop written inline cannot actually run;
`Monitor` is the mechanism that can.

```
Monitor({
  description: "CI review on PR <N>",
  persistent: true,
  command: `
    until out=$(gh api "/repos/{owner}/{repo}/issues/$PR_NUMBER/comments?since=$PUSH_TIME" \
                 --jq '.[] | select(.user.login=="claude[bot]") | "review posted: \\(.html_url)"' 2>/dev/null) \
          && [ -n "$out" ]; do
      # Surface a failed review run too — a review that errored never posts,
      # and waiting silently forever is indistinguishable from waiting normally.
      gh run list --workflow=claude-code-review.yml --branch "$(git branch --show-current)" \
        --limit 1 --json conclusion --jq '.[] | select(.conclusion=="failure") | "review run FAILED"'
      sleep 30
    done
    echo "$out"
  `,
})
```

The failure branch is not optional. A monitor that matches only the success signal
is silent through a crashed reviewer, and silence looks exactly like "still
running" — which is how you end up waiting forever on a review that will never
arrive. If the review run failed, read its log and proceed rather than waiting.

On the very first iteration only: also accept an existing unprocessed review
submitted before `PUSH_TIME`.

**Step 4 — Process review**

Read the review content and apply the YAGNI filter:

**Implement (high signal):**
- Bugs — correctness issues with concrete impact
- Security / data-loss risks
- CLAUDE.md violations
- Missing tests for shipped behaviour

**Defer (low signal → `gh issue create --label technical-debt --body-file -`, or
`--label enhancement` when the finding is genuinely a feature request; add one
`area:*` from the repo's existing set):**
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

**Step 1 — Watch CI**

Use the `Monitor` tool. One event per check as it reaches a terminal state; the
command exits on its own when nothing is pending, which ends the watch.

```
Monitor({
  description: "CI checks on PR <N>",
  persistent: true,
  command: `
    prev=""
    while true; do
      s=$(gh pr checks $PR_NUMBER --json name,bucket 2>/dev/null) || { sleep 30; continue; }
      cur=$(jq -r '.[] | select(.bucket!="pending") | "\\(.name): \\(.bucket)"' <<<"$s" | sort)
      comm -13 <(echo "$prev") <(echo "$cur")
      prev=$cur
      jq -e 'all(.bucket!="pending")' <<<"$s" >/dev/null && break
      sleep 30
    done
  `,
})
```

This emits **every** terminal bucket — `fail` and `cancel` as well as `pass` — so
a broken check announces itself instead of being absorbed into silence. Do not
narrow the filter to passes.

While it runs you are free to work; events arrive as notifications. Do not
re-invoke `gh pr checks` in a loop alongside it.

**Step 1a — Stuck detection (CRITICAL)**

Check once before arming the monitor, and again if it produces no events:

```bash
gh pr view $PR_NUMBER --json mergeable,mergeStateStatus
```

If `mergeStateStatus` is `DIRTY` or `mergeable` is `CONFLICTING`:
- **This is why CI is stuck** — GitHub Actions will not run on a conflicting branch
- `TaskStop` the monitor, jump back to **Stage 1** (Resolve Conflicts) and rebase
- Do NOT leave the monitor armed against a branch that will never produce checks

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
  then **run Stage 2's Step 2b and Step 3** — incremental review, push, post the
  artefact — and go back to Step 1.

  **Do NOT wait for the CI code review in this phase.** That is the only thing
  skipped here. The local review is not: CI asserts the head sha has been
  reviewed, so a fix pushed without an artefact turns the PR red and the loop
  never converges. These deltas are tiny — a lint fix selects Tier A alone, two
  agents — so the cost is small and the invariant stays absolute: **every sha
  that reaches CI has been locally reviewed.** An invariant with one exception is
  an invariant nobody can rely on.

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
