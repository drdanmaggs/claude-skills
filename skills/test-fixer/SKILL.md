---
name: test-fixer
description: Diagnose and fix test failures across any framework (Playwright, Vitest, Jest, Testing Library, etc.). Use when tests fail, are flaky, throw errors, or behave unpredictably. Auto-triggers on keywords like "test failing", "test broken", "flaky test", "intermittent failure", or when viewing test error output. Uses intelligent triage, automatic documentation consultation, and pattern learning to accelerate diagnosis.
---

# Test Fixer

Fix tests using: triage → memory check → diagnosis → fix → **MANDATORY checkpoints** → pattern search.

## Workflow Overview

```
Step 0: Git status (verify clean tree)
  ↓
Step 1: Fast triage (already fixed? flaky vs failing?)
  ↓
Step 0.5: Memory check (seen this before?)
  ↓ (if not in memory)
Step 2: Root cause analysis (bug in code vs test vs framework)
  ↓
Step 3: Value assessment (worth fixing or delete?)
  ↓
Step 4 (Failing) OR Step 5 (Flaky): Apply fix
  ↓
✅ CHECKPOINT 1: Record to memory (MANDATORY)
  ↓
✅ CHECKPOINT 2: Pattern search (Step 7 - MANDATORY)
  ↓
✅ CHECKPOINT 3: Unskip verification (MANDATORY)
  ↓
/ship
```

**CRITICAL:** Never ship without hitting all three checkpoints. Tests left with `.skip` are not fixed.

---

## Step 0: Git Status Check

```bash
git status  # Verify clean working tree before starting
```

Branch is created at `/ship` time — no branch setup needed.

---

## Step 1: Fast Triage

**Goal:** Determine if already fixed, flaky, or failing.

### Check if Already Fixed

```bash
# Test on main
git stash && git checkout main && npm test -- path/to/test.spec.ts -t "test name"
git checkout - && git stash pop

# Check recent fixes
git log --oneline -5 -- path/to/test.spec.ts
gh pr list --search "fix test" --state all --limit 5
```

✅ **If passes on main:** Pull/rebase, verify, done.

### Check for Flaky-Test GitHub Issue (CRITICAL)

```bash
# Search for existing flaky-test issue
gh issue list --label "flaky-test" --state open --search "in:title \"[test name]\""
```

⚠️ **If issue exists:** Even if test passes now, MUST do Step 5.5 (Deep Investigation). Flaky tests don't fail consistently - single pass proves nothing.

### Classify: Flaky vs Failing

**Run 10x in parallel:**

```bash
seq 10 | xargs -I {} -P 5 npm test -- path/to/test.spec.ts -t "test name"
```

**Results:**

- 10/10 fail → **Failing test** (Step 4)
- 3-7/10 fail → **Flaky test** (Step 5)
- 10/10 pass + has flaky-test issue → **Step 5.5** (Deep Investigation)
- 10/10 pass, no issue → Already fixed

**Flaky indicators:**

- "Cannot read property of undefined" (timing)
- "Element not found" (race condition)
- Passes alone, fails in suite
- Different errors on different runs

**Failing indicators:**

- Same error every time
- Logic bug (wrong value, type error)
- Started failing after specific commit

---

## Step 0.5: Memory Check (MANDATORY)

**ALWAYS check memory before deep analysis:**

```bash
# Get project hash
PROJECT_HASH=$(echo -n "$(git config --get remote.origin.url 2>/dev/null || git rev-parse --show-toplevel)" | md5sum | cut -d' ' -f1)

# Search for similar pattern
grep "[error keyword]" ~/.claude/skills/test-fixer/memory/$PROJECT_HASH/common-failures.md
```

✅ **If found in memory:**

- Apply known fix
- Verify works
- Update occurrence count
- **SKIP to Checkpoint 1** (record again + Step 7)

❌ **If not found:**

- Proceed to Step 2
- After fix, record new pattern

See: `memory/README.md` for complete memory system.

---

## Step 2: Root Cause Analysis (Opus + Sequential Thinking + Context7)

**Goal:** Determine if test caught real bug or if test itself is wrong.

### Quick Pattern Match (30 seconds)

**Before Sequential Thinking, check these common patterns:**

1. **Error: "Cannot read properties of null" + passes alone, fails in suite**
   - Quick diagnosis: `/docs/avoiding-flakey-tests.md#state-leakage-and-mock-contamination`
   - Check: Does test use `vi.clearAllMocks()` in `beforeEach`?
   - Prevention: `~/.claude/rules/testing.md` (Vitest/Integration section)

2. **Error mentions "timeout" or "Element not found"**
   - Quick diagnosis: `/docs/avoiding-flakey-tests.md#nextjs-hydration-gap`
   - Check: Does test click elements immediately after `page.goto()`?
   - Prevention: `~/.claude/rules/testing.md` (Playwright/E2E section)

3. **Test uses `vi.clearAllMocks()` in `beforeEach`?**
   - Quick fix: `~/.claude/rules/testing.md` (Mock Safety section)
   - Solution: Remove `vi.clearAllMocks()` if module-level mocks exist

4. **Test uses `waitForTimeout()` or `page.waitForTimeout()`?**
   - Quick fix: `~/.claude/rules/testing.md` (Timing Anti-Patterns section)
   - Solution: Replace with state assertion

**If no quick match:** Proceed with full Sequential Thinking + exploration below.

### Full Analysis with Explore Agent

**Use Explore agent with Opus:**

```
Task tool:
- subagent_type: "Explore"
- model: "opus"
- description: "Analyze if test caught real bug"
- prompt: See references/sequential-thinking-prompts.md - Step 2 template
```

**Agent will:**

1. Check memory first
2. Use Sequential Thinking for systematic analysis
3. Consult Context7 if framework-related
4. Explore codebase
5. Determine: Bug in code | Bug in test | Framework gotcha | Uncertain

**Decision:**

- ✅ **Bug in code:** Fix code (Step 4)
- ❌ **Bug in test:** Fix test, then assess if worth keeping (Step 3)
- 🔧 **Framework gotcha:** Apply workaround, record in memory
- 🤔 **Uncertain:** Ask user

**Auto-create issues for incidental bugs:**
If you discover unrelated bugs during investigation, create GitHub issues automatically (no approval needed). See `references/bug-analysis.md` for details.

---

## Step 3: Test Value Assessment (Opus + Sequential Thinking)

**Only if test itself is wrong** - determine if worth fixing or delete.

**Quick questions:**

1. Does test verify meaningful behavior or implementation detail?
2. Is this redundant (other tests cover this)?
3. Would I write this test today?

**Decision:**

- ✅ **Keep and fix:** Proceed to Step 4/5
- ❌ **Delete:** Remove test, commit with explanation, record in memory

See: `references/test-value-assessment.md` for full framework.

---

## Step 4: Failing Test Workflow

**For consistently broken tests.**

### 1. Gather Context (Parallel)

- Read test code
- Read implementation
- Check git history

### 2. Consult References

**Check memory first**, then:

- Context7: `references/context7-integration.md`
- Debugging: `references/debugging-workflow.md`
- Errors: `references/common-failures.md`
- Framework: `references/framework-specific.md`

### 3. Apply Fix & Verify

```bash
# Run specific test
npm test -- path/to/test.spec.ts -t "test name"

# Run full suite
npm test
```

### 4. ✅ CHECKPOINT 1: Record to Memory

**MANDATORY before commit:**

Add to `memory/[project-hash]/test-fixes.md`:

```markdown
## [Date] [Time] - [Test file]

**Test name:** [name]
**Category:** Failing
**Root cause:** [Bug in code|Bug in test|Framework|Environment]
**Fix applied:** [what changed]
**Confidence:** [High|Medium|Low]

---
```

If novel pattern, also add to `common-failures.md`. See `memory/README.md` for templates.

### 5. ✅ CHECKPOINT 2: Pattern Search (Step 7)

**MANDATORY - Skip to Step 7 now.**

---

## Step 5: Flaky Test Workflow

**For non-deterministic tests.**

### 1. Identify Pattern

**Check ALL in parallel:**

- Timing: arbitrary timeouts, missing waits
- State pollution: shared variables, no cleanup, **missing worker-scoped fixtures**
- External deps: unmocked API/database calls
- Non-determinism: timestamps, random values

### 1.5. Complex Patterns → Sequential Thinking (MANDATORY)

**If ANY of these patterns, use Opus + Sequential Thinking BEFORE fixing:**

- Passes alone, fails in suite (parallel execution)
- Database isolation issues
- Framework-specific timing edge cases
- Race conditions
- Novel pattern not in memory

See `references/sequential-thinking-prompts.md` for template.

### 2. Consult References

**Check isolation pattern first:**

- Integration test using beforeAll/afterAll? → Migrate to worker-scoped fixtures
- See: `~/.claude/rules/test-data-isolation.md`

**Then check:**

- Memory: `common-failures.md | grep -A5 "FLAKY"`
- Context7: `references/context7-integration.md`
- Framework: `references/framework-specific.md`
- Patterns: `references/common-patterns.md`

### 3. Apply Fix

**Common fixes:**

- Replace arbitrary timeouts with proper waits
- Implement test isolation (beforeEach/afterEach)
- Mock external dependencies
- Mock time: `vi.setSystemTime(new Date('2026-02-14'))`
- Migrate to worker-scoped fixtures

### 4. Verify Stability (CRITICAL)

**Run 20x in parallel (not 10):**

```bash
seq 20 | xargs -I {} -P 5 npm test -- path/to/test.spec.ts -t "test name"
```

**Results:**

- **20/20 pass (100%)** → ✅ Fixed! Continue to Checkpoint 1
- **1-19/20 pass (partial)** → ⚠️ **STILL FLAKY** → Auto-continue to Deep Analysis (max 3 iterations)
- **0/20 pass** → ❌ Different approach needed

**NEVER accept <100% pass rate as "fixed".** Even 95% means still flaky. If partial improvement, skill automatically applies deep analysis (Sequential Thinking + Context7 + test redesign).

### 5. ✅ CHECKPOINT 1: Record to Memory

**MANDATORY before commit:**

Add to `memory/[project-hash]/test-fixes.md` with FLAKY category.

### 6. ✅ CHECKPOINT 2: Pattern Search (Step 7)

**MANDATORY - Skip to Step 7 now.**

---

## Step 5.5: Deep Investigation for Previously Flagged Tests

**⚠️ MANDATORY when test has `flaky-test` GitHub issue.**

**Why:** Flaky tests don't fail consistently. Single pass proves nothing.

### Workflow

1. **Review GitHub issue:** `gh issue view [issue-number]`
2. **Extended testing:**

   ```bash
   # 20x parallel
   seq 20 | xargs -I {} -P 5 npm test -- path/to/test.spec.ts -t "test name"

   # Multiple conditions
   npm test -- path/to/test.spec.ts -t "test name"  # Alone
   npm test  # Full suite
   npm test -- --maxWorkers=1 path/to/test.spec.ts  # Sequential
   ```

3. **Code analysis (Opus + Sequential Thinking):**
   - Review test for latent flaky patterns
   - Even if 20/20 pass, check for timing/state/async issues
   - Consult Context7 for framework-specific patterns

4. **Decision:**
   - **HIGH confidence (no patterns, 20/20 pass):** Remove .skip(), close issue in commit
   - **MEDIUM/LOW confidence (patterns found):** Fix patterns first, re-verify
   - **Still flaky:** Update issue, keep investigating

5. **Update issue:** Comment with investigation summary before closing

**Don't manually close issues** - use `Closes #[issue]` in commit message.

---

## Step 7: Proactive Pattern Search & Fix (MANDATORY)

**⚡ AUTOMATIC after successful fix - prevents future failures.**

### When to Run

**Run when ALL true:**

- ✅ Fix verified (100% pass rate)
- ✅ Pattern is recurring type (timing, state, framework gotcha)
- ✅ Pattern has searchable code signature

**Skip if:**

- Typo or one-off bug
- Already part of batch fix
- User says "skip pattern search"

### Workflow

**1. Extract pattern:**

- Root cause: Timing | State | External dep | Framework | Parallel execution
- Code signature: `setTimeout(` | `waitForTimeout(` | `let sharedVar` | `beforeAll` without fixtures
- Framework: Playwright | Vitest | etc.

**2. Search for similar (Explore agent):**

```
Task tool:
- subagent_type: "Explore"
- model: "sonnet"
- description: "Find tests with similar pattern"
- prompt: Search for code signature in test files
```

**3. Create task list:**
For each similar test found, create task via TaskCreate.

**4. Apply fixes (loop):**
For each task:

- Apply same fix pattern
- **Verify:** 20x parallel (flaky) or full suite (failing)
- **20/20 pass:** Mark complete, continue
- **1-19/20 pass:** Apply deep analysis (max 3 iterations)
- **0/20 pass:** Rollback, mark failed, create issue

**5. Stage all pattern fixes ready for /ship:**

Ensure all batch fixes are staged. The commit and PR will be handled by `/ship` at the end of the workflow.

**6. Record meta-pattern:**
Add batch fix entry to `memory/[project-hash]/common-failures.md`.

### User Interaction

- **<10 similar tests:** Automatic
- **≥10 similar tests:** Prompt for confirmation
- **Can interrupt (Ctrl+C):** Current task completes, rest remain in todo

---

## ✅ CHECKPOINT 3: Unskip Verification (MANDATORY)

**ALWAYS run before commit — even if you're sure:**

```bash
# Find any remaining skip modifiers in the test file you fixed
grep -n "\.skip\|\.todo\|xtest\|xit\|xdescribe" path/to/test.spec.ts
```

**If any `.skip` / `.todo` / `xtest` / `xit` / `xdescribe` found:**

- Was it there before you started? → Leave it (not your responsibility)
- Is it on the test you fixed? → **REMOVE IT NOW** before proceeding

This is the #1 cause of PRs that "fix" tests but leave them skipped.

---

## Final Step: /ship

**Requirements before calling `/ship`:**

- ✅ All tests passing
- ✅ No compiler/linter warnings
- ✅ Memory recorded (Checkpoint 1)
- ✅ Pattern search completed (Checkpoint 2 - Step 7)
- ✅ **Unskip verified (Checkpoint 3)** — no `.skip`/`.todo` on tests you fixed

Once all checkpoints pass, invoke `/ship`. It will commit, lint/type-check, run code review, fix any issues, verify CI, and create the PR.

**Separate structural and behavioral commits** if needed before shipping (see `~/.claude/rules/commit-discipline.md`).

---

## Quick Reference

### Verification Standards

| Test Type          | Verification Command                                        | Success Criteria        |
| ------------------ | ----------------------------------------------------------- | ----------------------- |
| Flaky              | `seq 20 \| xargs -I {} -P 5 npm test -- [file] -t "[name]"` | 20/20 pass (100%)       |
| Failing            | `npm test`                                                  | All pass                |
| Previously flagged | Extended testing (20x parallel + multiple conditions)       | 20/20 in all conditions |

### Memory Commands

```bash
# Get project hash
PROJECT_HASH=$(echo -n "$(git config --get remote.origin.url 2>/dev/null || git rev-parse --show-toplevel)" | md5sum | cut -d' ' -f1)

# Search memory
grep "[keyword]" ~/.claude/skills/test-fixer/memory/$PROJECT_HASH/common-failures.md

# Record fix (append to test-fixes.md)
# See memory/README.md for templates
```

### Reference Files

- **Memory:** `memory/README.md` - Pattern storage system
- **Root cause:** `references/bug-analysis.md` - Bug vs test analysis
- **Value:** `references/test-value-assessment.md` - Worth fixing?
- **Failing:** `references/debugging-workflow.md`, `common-failures.md`, `framework-specific.md`
- **Flaky:** `references/common-patterns.md`, `framework-specific.md`
- **Context7:** `references/context7-integration.md` - Framework docs queries
- **Templates:** `references/sequential-thinking-prompts.md` - ST templates for Steps 2 & 3

---

## MANDATORY Checkpoints Reminder

**Before committing, ALWAYS:**

1. ✅ **CHECKPOINT 1: Record to memory**
   - Add to `test-fixes.md`
   - Add to `common-failures.md` if novel pattern
   - See `memory/README.md` for templates

2. ✅ **CHECKPOINT 2: Pattern search (Step 7)**
   - Extract fix pattern
   - Search for similar tests (Explore agent)
   - Fix similar tests automatically
   - Record meta-pattern

3. ✅ **CHECKPOINT 3: Unskip verification**
   - `grep -n "\.skip\|\.todo\|xtest\|xit\|xdescribe" path/to/test.spec.ts`
   - Remove `.skip` / `.todo` from ANY test you fixed
   - A "fixed" test that's still skipped is NOT fixed

**These are NOT optional.** They prevent future failures and build knowledge.

If you find yourself about to ship without doing these, STOP and run all three checkpoints first.

**After all three checkpoints pass → invoke `/ship`.**
