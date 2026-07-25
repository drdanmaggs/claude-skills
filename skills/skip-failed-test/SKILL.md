---
name: skip-failed-test
description: Handle test failures blocking PR progress when tests appear unrelated to current work. Use when tests fail on your branch or in CI but seem unrelated to your changes. Analyzes connection between failing test and your work using codebase exploration and sequential thinking. If unrelated and flaky, skips test and creates documented GitHub issue. If related, routes to test-fixer skill. Pragmatic workflow to keep PRs moving without ignoring real issues. Auto-triggers on phrases like "test is now failing", "different test failing", "blocking PR", "unrelated test failure", "CI failing on", or when multiple tests fail during PR work.
context: fork
---

# Skip Failed Test

Pragmatically handle test failures that block PR progress but may be unrelated to your work.

## When to Use This Skill

### Auto-Trigger Conditions

This skill automatically triggers when it detects:
- **Test failure blockers:** "test is now failing", "different test failing", "another test failed"
- **PR blockers:** "blocking PR", "CI failing on", "CI blocked by"
- **Unrelated failures:** "unrelated test failure", "seems unrelated", "different test"
- **Triage needed:** Multiple tests failing, or uncertainty about which test to fix

### vs. test-fixer Skill

Use **skip-failed-test** (this skill) when:
- ❓ Uncertain if test failure is related to your work
- ❓ Multiple tests failing, need to triage which to fix
- ❓ PR is blocked and need pragmatic progress

Use **test-fixer** directly when:
- ✅ Test is clearly related to your changes
- ✅ Single test failure that needs diagnosis/fix
- ✅ Investigating test patterns generally

**This skill is the router** - it analyzes relationship and routes to test-fixer if needed.

### Scenarios

**Scenario 1: Local testing - test fails on your branch**
- Working locally (may or may not have pushed yet)
- Run tests, one fails
- Failure seems unrelated to your changes
- Need to determine: Skip it or fix it?
- **Result:** Commit skip locally, DON'T push unless there's already a PR

**Scenario 2: CI testing - tests pass locally, fail in CI**
- Local tests all pass
- Pushed branch, CI pipeline fails on specific test
- Likely flaky, environment-specific
- **Result:** Commit skip + push to retrigger CI and unblock PR

## Workflow Overview

0. **Ensure Latest Code** (~30 sec) — Rebase from origin/main; test may pass now
1. **Fast-Path Check** (~30 sec) — Obvious unrelated → skip immediately
2. **Full Analysis** (~4 min) — Deep investigation → route to test-fixer or skip
3. **Execute Decision** — Skip test, delete test, or route to test-fixer

### ⏱️ Time Limits & Escape Hatches

**Maximum analysis time: 5 minutes total**

If analysis exceeds limits:
- Fast-path check > 30 seconds → Proceed to full analysis
- Explore agent > 90 seconds → Skip Explore, continue with manual inspection only
- Sequential thinking stalled → Default to routing to test-fixer (safer than skipping)
- Total workflow > 5 minutes → Ask user for guidance

**Default when uncertain: Route to test-fixer** (safer than skipping)

---

### Step 0: Ensure Latest Code (~30 seconds)

**Goal:** Verify test failure isn't due to stale branch state.

Many "unrelated" test failures are actually caused by:
- Branch diverged before a fix landed on main
- Test broke on main after the PR branch was created
- Branch is missing recent changes that would make the test pass

#### Actions:

1. **Fetch latest from origin:**
   ```bash
   git fetch origin
   ```

2. **Check for uncommitted changes (safety check):**
   ```bash
   git status --porcelain
   ```

   **If uncommitted changes exist:**
   - ❌ **STOP:** Warn user: "Uncommitted changes detected. Please commit or stash before rebasing."
   - Ask user to handle manually, then re-run skill
   - **Do NOT proceed with rebase**

3. **Check if in detached HEAD state:**
   ```bash
   git branch --show-current
   ```

   **If empty result (detached HEAD):**
   - ❌ **STOP:** "You're in detached HEAD state. Please checkout a branch before using this skill."

4. **Rebase from origin/main:**
   ```bash
   git rebase origin/main
   ```

   **Handle rebase outcomes:**
   - ✅ **Success** → Continue to step 5
   - ⚠️ **Already up-to-date** → Skip to Step 1 (no rerun needed)
   - ❌ **Conflicts** → Abort rebase, inform user:
     ```bash
     git rebase --abort
     ```
     Message: "Rebase conflicts detected. Please resolve manually with `git rebase origin/main`, then re-run skill."

5. **Re-run the failing test:**
   ```bash
   # Use the test name/path provided by user
   npm test -- path/to/test.spec.ts -t "test name pattern"
   ```

6. **Evaluate result:**
   - ✅ **Test passes** → **SUCCESS!** Report to user:
     ```
     ✅ Test failure resolved by rebasing to latest origin/main.
     The failure was due to stale branch state, not your changes.
     No skip needed. Branch is now ready for push/PR.
     ```
     **STOP HERE - mission accomplished!**

   - ❌ **Test still fails** → Continue to Step 1 (Fast-Path Check)

#### Skip This Step If:

You can opt out of Step 0 and proceed directly to analysis if:
- You've already rebased manually and confirmed test still fails on latest main
- You're working on a feature branch that intentionally diverges from main
- Time-sensitive: you need to skip analysis and unblock immediately

**To skip:** Tell Claude "skip rebase check, proceed to analysis"

#### Time Budget
- Fetch: ~5 sec
- Status checks: ~2 sec
- Rebase: ~10 sec
- Test rerun: ~10 sec
- **Total: ~30 sec** (adds minimal overhead)

---

### Step 1: Fast-Path Check (30 seconds max)

Before deep analysis, check if this is obviously unrelated:

1. **Quick git diff:**
```bash
git diff main...HEAD --stat
```

2. **Look at test file path and failing test name**

3. **Quick domain check:**
   - Different top-level directories? (e.g., `src/auth/` vs `src/billing/`)
   - Different business domains? (UI components vs API layer vs database)
   - CI-only failure? (passes locally)

**Decision:**
- ✅ **Obviously different domains + CI-only failure** → Skip immediately (proceed to Step 3)
- ❌ **Uncertain or same domain** → Proceed to Step 2 for full analysis

---

### Step 2: Full Analysis & Decision (max 4 minutes)

Only reach this step if Fast-Path didn't give clear answer.

#### A) Gather Context (parallel, 90 seconds max)

**Do all 3 simultaneously:**

1. **Check your changes:**
```bash
git diff main...HEAD -- '*.ts' '*.tsx' '*.js'
```

2. **Read failing test file:**
   - What functionality does it test?
   - What files/functions does it import?
   - What are its dependencies?

3. **Explore codebase connections (quick mode, 90 sec timeout):**

Use **Explore agent** (thorough = "quick") with focused task:

```
Search for direct imports or dependencies between:
- PR modified files: [list from git diff]
- Test file: [path to failing test]

Focus:
- Check if test imports any modified files
- Check if modified files import test dependencies
- Maximum depth: 1 level of indirect dependencies

Return: YES/NO with brief evidence (2-3 sentences max)
Time limit: 90 seconds
```

**If Explore doesn't return in 90 seconds:** Skip it, rely on manual inspection from steps 1-2

---

#### B) Analyze & Decide (single sequential thinking session, max 8 thoughts)

**⚡ Use Opus for this analysis** - Critical decision requiring deep reasoning.

Use **Sequential Thinking with max 8 thoughts** structured as:

**Thoughts 1-3: Analyze Connection**
- What did the PR actually change? (from git diff)
- What does the failing test actually test? (from test file)
- Is there a dependency/import path? (from Explore agent or manual inspection)
- Are they in the same domain/feature area?

**Thoughts 4-5: Assess Confidence Level**

Use 2-tier framework:

**CLEARLY UNRELATED** (safe to skip):
- ✅ Different domains (auth vs billing, UI vs API, frontend vs backend)
- ✅ CI-only failure (passes locally) OR intermittent
- ✅ No import path found (test doesn't use modified code)
- ✅ Error doesn't reference modified files

**UNCERTAIN** (needs deeper reasoning):
- Everything else (indirect connections, same domain, theoretical side effects, etc.)

**Thoughts 6-8: Make Decision**

**If CLEARLY UNRELATED:**
- Assess test value (is it worth keeping?)
- If valuable: Skip + document
- If meaningless: Delete instead

**If UNCERTAIN:**
- Is there a **plausible mechanism** for the changes to affect this test?
- Is the failure logic-related or timing/environment-related?
- Decision: Route to test-fixer OR Skip with thorough documentation

**Final Decision (Thought 8):**
- **Route to test-fixer** (if connected or uncertain with plausible mechanism)
- **Skip + document** (if clearly unrelated OR uncertain but timing/environment only)
- **Delete test** (if unrelated AND meaningless/redundant)

---

### Step 3: Execute Decision

Based on the decision from Step 2:

#### → Route to /test-fixer

```
Too risky to skip - must investigate the failure.
Route to /test-fixer skill for diagnosis and fix.
```

Use when:
- Direct or indirect dependency found
- Same feature area
- Consistent failure (not flaky)
- Plausible mechanism for changes to affect test
- When uncertain (safer to investigate than skip)

---

#### → Delete Test (If Meaningless)

If test is both **unrelated** AND **meaningless/redundant**:

```bash
# Delete the test entirely
git rm path/to/test.spec.ts  # or remove specific test from file

git commit -m "test: remove meaningless test unrelated to PR

Test verified [implementation detail / trivial assertion]
rather than meaningful behavior. Was failing but unrelated
to current PR work.

Coverage maintained by [other tests]. Better to delete
than skip and maintain low-value test."
```

**Principle:** Don't accumulate skip debt for garbage tests.

See [test-value-assessment.md](../test-fixer/references/test-value-assessment.md) for framework.

---

#### → Skip Test & Document (If Valuable but Unrelated)

1. **Skip the test:**
```typescript
// In test file
test.skip('flaky test name', async () => {
  // ... test code
});
```

Or for Vitest:
```typescript
test.skip('flaky test name', () => {
  // ... test code
});
```

2. **Create detailed GitHub issue** (use all context gathered):

```markdown
Title: [Flaky Test] Test name is blocking PRs - unrelated to changes

## Context
This test is failing on branch `[branch-name]` but appears unrelated to the PR work.

## PR Being Blocked
- PR: #[number] or [branch name]
- PR changes: [brief description]
- Files modified: `[list main files]`

## Failing Test
- **Test:** `[full test path and name]`
- **Error:**
  ```
  [paste error message]
  ```

## Why Unrelated
[Explain analysis from sequential thinking]
- PR touches: [X, Y, Z]
- Test exercises: [A, B, C]
- No connection found because: [reasoning from thoughts 1-5]

## Flakiness Evidence
- [ ] Fails in CI, passes locally
- [ ] Fails intermittently (passes sometimes)
- [ ] Error suggests timing issue
- [ ] Test has flaky patterns (timeouts, shared state, etc.)
- [ ] Using suite-scoped beforeAll/afterAll instead of worker fixtures (integration tests)

## Next Steps
1. Investigate root cause of flakiness
2. Fix using patterns from test-fixer skill
3. Remove `.skip()` once fixed

## Related Commits
- Failing started: [commit hash if known]
- PR branch: [branch name]

Labels: flaky-test, technical-debt, tests
```

3. **Commit the skip:**
```bash
git add path/to/test.spec.ts
git commit -m "test: skip flaky test blocking PR

Temporarily skip [test name] which is failing but unrelated
to current PR work. Documented in issue #[number].

The test appears flaky - [brief reason, e.g., 'timing issue',
'CI-only failure', 'shared state'].

Will be fixed separately to unblock PR progress."
```

4. **Push to retrigger CI (ONLY if blocking active PR):**

**First, check the context:**
```bash
# Check if branch exists on remote
git branch -r | grep "origin/$(git branch --show-current)"

# Check if there's a PR
gh pr view --json state 2>/dev/null || echo "No PR found"
```

**Decision:**
- ✅ **Push if:** Branch exists on remote AND there's an active PR with CI running
  ```bash
  git push  # Retriggers CI with test now skipped
  ```
  **Why:** CI needs to rerun with the skipped test to unblock the PR

- ❌ **DON'T push if:** Working locally, no remote branch yet, or no PR
  ```bash
  # Just commit locally - will be pushed later with other work
  # Nothing more to do
  ```
  **Why:** Pushing creates remote branch unnecessarily. User will push when ready.

5. **Continue with PR** - test is documented, tracked, won't be forgotten

---

## Important Guidelines

### When to Skip vs Fix

**CLEARLY UNRELATED → Skip with documentation**
- Different domains, CI-only/intermittent, no imports, error doesn't reference your code
- Create detailed GitHub issue documenting analysis
- Commit skip with clear explanation
- Continue with PR progress

**UNCERTAIN → Use Sequential Thinking (Opus, max 8 thoughts)**
- Indirect connection possible OR same domain OR theoretical side effect
- Reason through: plausible vs theoretical, logic vs timing, impact mechanism
- If plausible mechanism + logic-related → Must route to /test-fixer
- If theoretical only OR timing/environment → Skip with thorough documentation

**When in doubt: Route to test-fixer** (safer than skipping)

**Additional considerations:**
- ⚠️ Critical path tests (auth, payments, data integrity) require extra scrutiny
- ⚠️ Team/CI process must support temporary skips
- ⚠️ Every skip MUST have detailed GitHub issue with full context
- ⚠️ Would skipping significantly delay PR progress? (Part of pragmatic decision)

### Robust CI Assumption

This workflow assumes:
- Your CI is generally robust
- Tests usually pass on main/master
- Failures are exceptions, not norm
- Team has process for tracking skipped tests

If CI is frequently broken, different workflow needed.

### Avoid Skip Debt

**After skipping:**
- Issue MUST be created (no exceptions)
- Issue MUST have full context (copy error, explain analysis)
- Issue should be prioritized for fixing
- Regular review of skipped tests

**Track skipped tests:**
```bash
# Find all skipped tests
grep -r "test.skip\|it.skip" tests/

# Count skipped tests
grep -r "test.skip\|it.skip" tests/ | wc -l
```

Don't let skipped tests accumulate. Fix them or remove them.

---

## Example Scenarios

### Scenario A: Fast-Path - Clearly Unrelated

**Your changes:** Added new user profile component in `src/components/profile/`
**Failing test:** Payment processing test in `tests/api/billing/payment.test.ts` fails in CI
**Fast-Path Check:**
- ✅ Different top-level directories (components vs api/billing)
- ✅ Different domains (UI component vs payment API)
- ✅ CI-only failure (passes locally)
**Decision:** Skip immediately (Fast-Path), create GitHub issue
**Time:** < 30 seconds

### Scenario B: Uncertain - Route to test-fixer

**Your changes:** Refactored auth hook in `src/hooks/useAuth.ts`
**Failing test:** Dashboard test in `tests/pages/dashboard.test.ts` fails consistently
**Analysis (Sequential Thinking, 6 thoughts):**
- Thought 1-2: PR modified useAuth, test imports Dashboard which uses useAuth
- Thought 3: Explore agent: YES - direct import path found
- Thought 4-5: UNCERTAIN confidence (same domain, direct dependency)
- Thought 6: Plausible mechanism - auth changes could break dashboard
**Decision:** Route to /test-fixer - must investigate
**Time:** ~2 minutes

### Scenario C: Skip - Flaky but Valuable

**Your changes:** Updated button styles in `src/components/ui/button.tsx`
**Failing test:** E2E checkout flow timeout in CI, passes locally 5/5 times
**Analysis (Sequential Thinking, 7 thoughts):**
- Thought 1-2: PR only touched CSS, test exercises full checkout flow
- Thought 3: Explore agent: NO import path (CSS doesn't affect flow logic)
- Thought 4-5: CLEARLY UNRELATED (different domains, CI-only, no imports)
- Thought 6: Test is valuable (critical checkout flow)
- Thought 7: Decision: Skip + document as flaky
**Decision:** Skip + create detailed GitHub issue
**Time:** ~2 minutes

### Scenario D: Delete - Meaningless Test

**Your changes:** Added API endpoint in `src/pages/api/users/[id].ts`
**Failing test:** Trivial assertion test checking import statement syntax
**Analysis (Sequential Thinking, 5 thoughts):**
- Thought 1-2: PR added API endpoint, test verifies import syntax
- Thought 3: CLEARLY UNRELATED (different concern)
- Thought 4: Test value: Meaningless (linter handles this)
- Thought 5: Decision: Delete instead of skip
**Decision:** Delete test entirely
**Time:** ~90 seconds

---

## Quick Decision Flow

```
Test fails on branch
    ↓
Step 0: Ensure Latest (30 sec)
- git fetch origin
- git rebase origin/main
- Re-run test
    ↓
┌──────────┬────────────┐
│ Passes   │ Still Fails│
│    ↓     │     ↓      │
│  Done!   │  Step 1:   │
│ (rebased │  Fast-Path │
│  fixed)  │  (30 sec)  │
│          │     ↓      │
│          │ Different  │
│          │  domains?  │
│          │  CI-only?  │
│          │     ↓      │
│          │ ┌───────┬──┐
│          │ │Obvious│Un│
│          │ │Unrel  │c.│
│          │ │   ↓   │↓ │
│          │ │ Skip  │St│
│          │ │ (doc) │e │
│          │ │       │p2│
│          │ │       │↓ │
│          │ │       │An│
│          │ │       │al│
│          │ │       │↓ │
│          │ │       │Ro│
│          │ │       │ut│
│          │ │       │e │
└──────────┴─┴───────┴──┘

Total time: 30 sec (rebase fixes) - 5 min max (full analysis)
```

**Key:** Rebase first to catch stale branch issues. Fast-path for obvious cases. Full analysis with time limits for uncertain cases.

---

## Tools to Use

**For analysis:**
- Fast git diff: `git diff main...HEAD --stat`
- Detailed git diff: `git diff main...HEAD -- '*.ts' '*.tsx' '*.js'`
- Explore agent (quick mode, 90 sec timeout) - focused import search only
- Sequential thinking (max 8 thoughts) - unified analysis session
- Git log: `git log --oneline -10` to see recent changes

**For documentation:**
- GitHub issue with full context
- Clear title: `[Flaky Test] Test name - blocking PRs`
- Labels: `flaky-test`, `technical-debt`, `tests`

**For fixing later:**
- /test-fixer skill when ready to address the flakiness

---

## Integration with Other Skills

**This skill is the router:**
- If test is related → Routes to `/test-fixer`
- If test is unrelated + flaky → Skips + documents
- Uses Explore (quick mode) and Sequential Thinking (8 thoughts max) during analysis

**Don't use this skill if:**
- You haven't confirmed the test is failing (run the test suite first)
- Test is clearly related to your work (use `/test-fixer` directly)
- You're investigating test patterns generally (use `/test-fixer` for that)

Use this skill specifically for the **PR blocker** situation where pragmatic progress is needed.
