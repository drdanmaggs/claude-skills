---
name: critical-path-testing
description: "Risk-driven testing — identify and test critical user paths first, coverage is an output not the goal"
---

# Critical Path Testing Skill

**Type:** Orchestrator (Multi-Phase)
**Triggers:** `/critical-path-testing`, "test critical paths", "risk-driven testing"
**Philosophy:** Quality over quantity. Coverage % is an OUTPUT, not the INPUT.

## Purpose

Generate production-ready tests for critical paths (auth, data integrity, payments) using risk scoring rather than coverage percentages. Tests are parallel-safe, non-flaky, and leverage patterns from test-fixer memory.

**Key Differences from test-coverage-retrofit:**
- **Risk-driven** (depth-first on critical paths) vs coverage-driven (breadth-first on all files)
- **Semantic analysis** (git history, dependencies, domain knowledge) vs pattern matching (filenames)
- **Baked-in robustness** (MANDATORY patterns from test-fixer) vs basic test generation
- **Memory integration** (30-50% fast path) vs no memory

## Workflow Overview

```
Phase 0: Discovery & Risk Assessment (60s)
  ├─ Discover session constants
  ├─ Calculate criticality scores (0-100)
  ├─ Check test-fixer memory
  └─ Generate test plan → USER APPROVAL REQUIRED

Phase 1: Test Generation (10 min for 20 files)
  ├─ Sonnet planners (understand criticality)
  ├─ Haiku/Sonnet writers (smart routing)
  ├─ Validation pass (enforce MANDATORY patterns)
  └─ Fix round (max 2 attempts)

Phase 2: Stability Verification (5 min)
  ├─ Run tests 5x in parallel
  ├─ Investigate failures (Opus)
  └─ Pre-commit validation

Phase 3: Pattern Learning (MANDATORY - 30s)
  ├─ Extract patterns from generated tests
  ├─ Record to test-fixer memory
  └─ Proactive search for similar gaps
```

---

## Phase 0: Discovery & Risk Assessment

### Step 0.1: Discover Session Constants
**Agent:** Explore (Sonnet, medium thoroughness)
**Task:** Extract project architecture patterns

**What to discover:**
- Test command format (`npm test`, `pnpm test`, etc.)
- Test file patterns (colocated vs centralized, `.test.ts` vs `.spec.ts`)
- Mocking philosophy from `~/.claude/rules/testing-server-actions.md`
- Type safety requirements from `~/.claude/rules/code-quality.md`
- Worker fixture patterns from `tests/helpers/vitest-worker-fixture.ts`
- E2E fixture patterns from `tests/e2e/fixtures/auth-fixture.ts`

**Output:** `SESSION_CONSTANTS` object:
```json
{
  "test_command": "pnpm test",
  "test_pattern": ".test.ts",
  "test_location": "colocated",
  "mocking_philosophy": "no_framework_mocking",
  "worker_fixtures": {
    "integration": "@/tests/helpers/vitest-worker-fixture",
    "e2e": "@/tests/e2e/fixtures/auth-fixture"
  },
  "type_safety": "strict"
}
```

**Reuse pattern:** Same as test-coverage-retrofit Stage 0.6

### Step 0.2: Calculate Criticality Scores
**Agent:** Explore (Sonnet) + Sequential Thinking
**Task:** Identify truly critical paths using semantic analysis

**Run scoring script:**
```bash
python ~/.claude/skills/critical-path-testing/scripts/calculate_criticality.py
```

**Scoring algorithm:** See `references/criticality-scoring.md`

**Output:** JSON file at `.claude/cache/criticality-scores-[timestamp].json`:
```json
{
  "lib/auth/login-logic.ts": {
    "score": 100,
    "breakdown": {
      "domain_category": 40,
      "risk_indicators": 25,
      "impact_radius": 20,
      "test_gap": 10
    },
    "reason": "Authentication core (40) + in test-fixer memory (15) + recent bug (10) + entry point (20) + no tests (10)",
    "category": "authentication",
    "test_type": "integration"
  }
}
```

**Thresholds:**
- **80-100: CRITICAL** → Phase 1 priority
- **60-79: HIGH** → Test if time permits
- **40-59: MEDIUM** → Backlog
- **<40: LOW** → Skip

### Step 0.3: Check Test-Fixer Memory
**Task:** Search memory for known patterns (30-50% fast path)

**Memory location:** `~/.claude/skills/test-fixer/memory/[project-hash]/`

**Search for:**
- `common-failures.md` → Do we test these failure modes?
- `test-fixes.md` → Similar code patterns?
- `critical-path-coverage.md` → Gaps from previous runs?

**Extract insights:**
- Common failure modes → Ensure new tests cover them
- Framework gotchas → Apply defensive patterns
- Rate limiting → Add retry logic
- CASCADE DELETE issues → Manual child-first deletion

**Output:** List of patterns to enforce in Phase 1

### Step 0.4: Generate Test Plan
**Task:** Write plan to `.claude/docs/critical-path-test-plan-[timestamp].md`

**Format:**
```markdown
# Critical Path Test Plan

Generated: [timestamp]
Project: [name]

## Priority 1: CRITICAL (Score 80-100)
- [ ] lib/auth/login-logic.ts (Score: 100, Type: integration)
  - Criticality: Authentication core + no tests + recent bug
  - Failure modes: Rate limiting, concurrent sessions
  - Required fixtures: workerHousehold, multipleUsers

- [ ] lib/payments/process-payment-logic.ts (Score: 95, Type: integration)
  - Criticality: Payment processing + high complexity
  - Failure modes: Idempotency, partial failures
  - Required fixtures: workerHousehold, paymentMocks

## Priority 2: HIGH (Score 60-79)
- [ ] app/api/users/route.ts (Score: 75, Type: integration)

## Patterns to Apply (From test-fixer memory)
- Worker-scoped fixtures (all integration tests)
- Retry logic for Supabase operations (rate limiting prevention)
- 30s timeouts for external services (CI reliability)
- Error checking on ALL DB operations (silent failure prevention)

## Known Gaps
Files not in scope but recommended for future:
- lib/auth/password-reset-logic.ts (Score: 85)
- lib/payments/refund-logic.ts (Score: 80)

## Estimated Effort
- Priority 1: 10 files, ~10 minutes
- Priority 2: 5 files, ~5 minutes
- Total: ~15 minutes
```

**Checkpoint:** Present plan to user with:
```
I've analyzed the codebase and identified X critical paths needing tests:

**Priority 1 (CRITICAL - Score 80-100):**
- lib/auth/login-logic.ts (100)
- lib/payments/process-payment-logic.ts (95)
[...list all...]

**Patterns to enforce:**
- Worker-scoped fixtures (parallel-safe)
- Error checking on all DB operations
- 30s timeouts for external services

This will generate production-ready tests in ~15 minutes.

Proceed with Phase 1? [yes/no]
```

**Wait for user approval before continuing.**

---

## Phase 1: Test Generation

### Step 1.1: Spawn Planners (Parallel)
**Agent:** Sonnet planner per file (up to 50 concurrent)
**Task:** Understand what's critical about THIS file

**Planner prompt:** See `references/planner-prompts.md`

**Each planner analyzes:**
- What's critical? (auth? data integrity? payments?)
- Known failure modes from test-fixer memory
- Integration requirements (DB? external API? auth?)
- Edge cases that matter for THIS domain
- Complexity level (simple utility vs complex state machine)

**Output per file:** `.claude/cache/test-plans/[file-hash].json`
```json
{
  "file": "lib/auth/login-logic.ts",
  "criticality": "authentication-core",
  "known_failure_modes": ["rate limiting", "concurrent sessions"],
  "test_strategy": "integration",
  "complexity": "high",
  "test_cases": [
    {
      "name": "should handle concurrent login attempts without race conditions",
      "priority": "HIGH",
      "pattern": "worker_fixtures_with_retry"
    },
    {
      "name": "should invalidate all sessions on password change",
      "priority": "HIGH",
      "pattern": "cascade_verification"
    }
  ],
  "required_fixtures": ["workerHousehold", "multipleUsers"],
  "external_dependencies": ["supabase_auth_api"],
  "recommended_model": "sonnet"
}
```

**Wait for all planners to complete before Step 1.2.**

### Step 1.2: Model Selection for Writers
**Task:** Use Sonnet for all test writing (user preference: quality > cost)

**Decision:**
```
ALL test writing → Sonnet writer
```

**Rationale:**
- Tests are infrastructure - quality matters more than generation cost
- Sonnet provides better edge case coverage across all criticality levels
- Consistent quality prevents flaky tests requiring fixes later
- User directive: "At least Sonnet, if not Opus" for all test writing

### Step 1.3: Spawn Writers (Parallel)
**Agent:** Sonnet (up to 20 concurrent)
**Task:** Generate robust tests with MANDATORY patterns

**Writer prompt includes:**

1. **SESSION_CONSTANTS** (from Phase 0.1)
2. **Planner output** (test cases, fixtures, failure modes)
3. **MANDATORY patterns** (see `references/mandatory-patterns.md`)
4. **Test-fixer memory insights** (from Phase 0.3)

**Key prompt sections:**

```markdown
MANDATORY PATTERNS (NON-NEGOTIABLE):

1. Worker-scoped fixtures:
   ```typescript
   import { test, expect } from "@/tests/helpers/vitest-worker-fixture";
   test("name", async ({ workerHousehold }) => { ... })
   ```

2. Unique IDs everywhere:
   ```typescript
   const id = crypto.randomUUID();
   const name = testName("Entity");
   ```

3. Error checking ALL DB operations:
   ```typescript
   const { data, error } = await supabase.from("table").insert({...});
   expect(error).toBeNull(); // CRITICAL - catches silent failures
   ```

4. Proper timeouts (30s for external services):
   ```typescript
   await expect(page).toHaveURL(/\/success/, { timeout: 30000 });
   ```

5. Known failure modes from test-fixer memory:
   [List specific patterns from Phase 0.3]

VERIFICATION:
- Write test file
- Run tests locally: [SESSION_CONSTANTS.test_command]
- For integration tests: Run 3 times to verify stability
- Report: PASSING | FAILED
```

**Output per file:** Test file written + verification result

### Step 1.4: Validation Pass (Parallel)
**Agent:** Sonnet validator per file (up to 30 concurrent)
**Task:** Enforce MANDATORY patterns with automated checks

**Validation script:**
```typescript
const validations = [
  {
    check: () => fileContains("workerHousehold") || fileContains("workerAuth"),
    msg: "Missing worker-scoped fixture import"
  },
  {
    check: () => !fileContains("TEST_USER_ID") && !fileContains("TEST_HOUSEHOLD_ID"),
    msg: "Hardcoded test ID found (violates isolation)"
  },
  {
    check: () => {
      const insertCount = countMatches(/\.insert\(/g);
      const errorChecks = countMatches(/expect\(error\)/g);
      return errorChecks >= insertCount;
    },
    msg: "Unchecked DB operations (missing error assertions)"
  },
  {
    check: () => !fileContains("timeout: 5000") && !fileContains("timeout: 10000"),
    msg: "Timeout too tight for CI (use 30000 for external services)"
  },
  {
    check: () => {
      const hasManualCleanup = fileContains("afterAll") || fileContains("afterEach");
      const hasSequential = fileContains("describe.sequential");
      if (hasManualCleanup && !hasSequential) return false;
      return true;
    },
    msg: "Manual cleanup without describe.sequential (use worker fixtures instead)"
  }
];
```

**Output:** `APPROVED | NEEDS_FIX { reasons: [...] }`

### Step 1.5: Fix Round
**For NEEDS_FIX files:**
1. Respawn writer with validator feedback
2. Include specific fix instructions
3. Max 2 attempts per file
4. If still failing → Mark as SKIPPED

**For SKIPPED files:**
- Create GitHub issue (auto, no approval)
- Template:
  ```markdown
  Title: Add tests for [file] - auto-generation failed
  Labels: testing, auto-generated, needs-manual-work

  Critical path testing identified `[file]` (Score: [X]) but auto-generation failed after 2 attempts.

  **Validation failures:**
  - [List reasons from validator]

  **Recommended approach:**
  - [Suggestions from planner]
  ```

**Commit passing tests:**
```bash
git add [test-files]
git commit -m "test: add critical path tests for [domain]

- lib/auth/login-logic.ts (100% worker-scoped, error-checked)
- lib/payments/process-payment-logic.ts (retry logic for rate limits)

Patterns applied: worker fixtures, unique IDs, 30s timeouts
From: /critical-path-testing skill
"
```

---

## Phase 2: Stability Verification

### Step 2.1: Parallel Execution Test
**Task:** Catch race conditions that pass sequentially

```bash
# Run NEW tests only, 5x in parallel
[SESSION_CONSTANTS.test_command] -- [new-test-files] --run --pool=threads --poolOptions.threads.singleThread=false
```

**Run 5 times, track results:**
```
Run 1: PASS
Run 2: PASS
Run 3: FAIL (lib/auth/login-logic.test.ts)
Run 4: PASS
Run 5: PASS
```

**Pass criteria:** 5/5 (100% pass rate required)

**If <5/5:** Proceed to Step 2.2 for failing files

### Step 2.2: Investigate Failures
**Agent:** Opus + Sequential Thinking
**Task:** Root cause analysis for flaky tests

**For each failing test file:**

**Investigation steps:**
1. Read test file
2. Read implementation file
3. Check schema for CASCADE DELETE: `grep -r "ON DELETE CASCADE" supabase/migrations/`
4. Check test-fixer memory for similar failures
5. Use Sequential Thinking to analyze root cause

**Common issues to check:**
- Timing issue? (add explicit waits)
- CASCADE DELETE race? (switch to manual child-first deletion)
- Auth rate limiting? (add retry logic with exponential backoff)
- Data pollution? (verify unique IDs used)
- Shared state? (verify worker fixtures used correctly)

**Resolution:**
- **If fixable:** Apply fix, re-run 5x
- **If not fixable in 2 attempts:** Mark as SKIPPED, create issue

**Output:** Updated test files OR GitHub issues

### Step 2.3: Pre-Commit Validation
**Task:** Ensure full test suite still passes

```bash
# Run FULL test suite (not just new tests)
[SESSION_CONSTANTS.test_command]

# Auto-fix linting
pnpm lint:fix

# Type check
pnpm type-check

# Format
pnpm format
```

**If any step fails:** Report to user, do not commit

**If all pass:**
```bash
git add -A
git commit -m "test: stabilize critical path tests

Fixed flaky behavior in:
- lib/auth/login-logic.test.ts (added retry logic)

All tests passing 5/5 parallel runs.
"
```

---

## Phase 3: Pattern Learning (MANDATORY)

### Step 3.1: Extract Patterns
**Task:** Analyze generated tests for reusable patterns

**Orchestrator analyzes:**
- What failure modes did we test for?
- What fixtures/helpers were created?
- What critical paths were covered?
- What patterns worked well?
- What patterns caused issues?

**Output:** Pattern summary

### Step 3.2: Record to Test-Fixer Memory
**MANDATORY checkpoint** (like test-fixer Step 7)

**Calculate project hash:**
```bash
WORKSPACE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_HASH=$(echo -n "$WORKSPACE_ROOT" | shasum -a 256 | cut -d' ' -f1 | head -c 32)
```

**Append to memory file:**
`~/.claude/skills/test-fixer/memory/$PROJECT_HASH/critical-path-coverage.md`

**Format:**
```markdown
## Session: [Date] - Critical Path Testing

### Files Tested
- lib/auth/login-logic.ts (Score: 100, Type: integration)
- lib/payments/process-payment-logic.ts (Score: 95, Type: integration)
[...list all...]

### Patterns Successfully Applied
- ✅ Worker-scoped fixtures (all integration tests)
- ✅ Error checking on all DB operations
- ✅ 30s timeouts for external services
- ✅ Retry logic for Supabase rate limiting

### Issues Encountered & Resolved
- Auth rate limiting during parallel test runs → Added exponential backoff retry
- CASCADE DELETE race condition in meals table → Switched to manual cleanup

### Gaps Identified
Files with high criticality scores but not tested this session:
- lib/auth/password-reset-logic.ts (Score: 85) - No tests exist
- lib/payments/refund-logic.ts (Score: 80) - Coverage <50%

### Fixtures Created
- None (reused existing worker fixtures)

### GitHub Issues Created
- #123: Add tests for password reset flow
- #124: Manual test needed for refund logic (auto-generation failed)
```

**Create memory file if doesn't exist:**
```bash
mkdir -p ~/.claude/skills/test-fixer/memory/$PROJECT_HASH
touch ~/.claude/skills/test-fixer/memory/$PROJECT_HASH/critical-path-coverage.md
```

### Step 3.3: Proactive Pattern Search
**Task:** Find similar critical files not yet tested (like test-fixer Step 7)

**Search codebase:**
```bash
# Find similar auth-related files
grep -r "export.*login\|export.*auth\|export.*session" lib/ app/ --include="*.ts" --exclude="*.test.ts"

# Find similar payment-related files
grep -r "export.*payment\|export.*transaction\|export.*billing" lib/ app/ --include="*.ts" --exclude="*.test.ts"

# Find similar data integrity files
grep -r "export.*create\|export.*update\|export.*delete" lib/ app/ --include="*.ts" --exclude="*.test.ts"
```

**Cross-reference with criticality scores:**
- Files with score >80 that weren't in this session's plan
- Files in test-fixer memory that aren't covered

**Present to user:**
```
Found 3 more critical files not in this session's plan:
- lib/auth/oauth-callback.ts (Score: 90) - Authentication
- lib/auth/session-refresh.ts (Score: 85) - Authentication
- lib/payments/refund-logic.ts (Score: 82) - Payment processing

Add these to backlog? [yes/no]
```

**If yes:** Create GitHub issues (auto, no approval)

**Issue template:**
```markdown
Title: Add tests for [file]
Labels: testing, critical-path, auto-generated

Critical path testing identified `[file]` (Score: [X]) as untested.

**Criticality breakdown:**
- Domain category: [X] points ([category])
- Risk indicators: [X] points ([details])
- Impact radius: [X] points ([details])
- Test gap: [X] points ([details])

**Recommended approach:**
- Test type: [integration|unit|e2e]
- Required fixtures: [list]
- Failure modes to cover: [list from planner if available]

**Pattern:** Similar to [tested-file] from this session.
```

---

## Success Criteria

**Phase 0 complete when:**
- ✅ Session constants discovered
- ✅ Criticality scores calculated
- ✅ Test-fixer memory checked
- ✅ Test plan generated and approved by user

**Phase 1 complete when:**
- ✅ All CRITICAL files (score 80-100) have tests OR issues created
- ✅ All tests pass validation (MANDATORY patterns enforced)
- ✅ Tests pass locally (1-3 runs)

**Phase 2 complete when:**
- ✅ Tests pass 5/5 parallel runs (100% stability)
- ✅ Full test suite passes
- ✅ Lint, type check, format all pass

**Phase 3 complete when:**
- ✅ Patterns recorded to test-fixer memory
- ✅ Proactive search completed
- ✅ Backlog issues created

---

## Configuration

**Model routing:**
- Phase 0.1: Explore (Sonnet, medium)
- Phase 0.2: Explore (Sonnet) + Sequential Thinking
- Phase 1.1: Sonnet planner (up to 50 concurrent)
- Phase 1.3: Sonnet writer (up to 20 concurrent)
- Phase 1.4: Sonnet validator (up to 30 concurrent)
- Phase 2.2: Opus + Sequential Thinking

**Parallelism limits:**
- Planners: 50 concurrent (CPU-bound, fast)
- Writers: 20 concurrent (I/O-bound, run tests locally)
- Validators: 30 concurrent (CPU-bound, grep-based)

**Cost estimate (20 critical files):**
- Phase 0: ~$0.10
- Phase 1: ~$0.50
- Phase 2: ~$0.20
- Phase 3: ~$0.05
- **Total:** ~$0.85

---

## When to Use

**Use critical-path-testing when:**
- Starting a new feature with auth/payment/data integrity
- High-risk refactoring (authentication, billing)
- Production bug fix (prevent regression)
- Security audit findings
- Before major release

**Use test-coverage-retrofit when:**
- Legacy codebase needs comprehensive coverage
- Aiming for 95% coverage across all code
- Low-risk utilities and helpers need coverage

**Both are complementary:**
- critical-path-testing → Depth (critical paths tested thoroughly)
- test-coverage-retrofit → Breadth (all code has basic coverage)

---

## References

- `references/criticality-scoring.md` - Scoring algorithm details
- `references/mandatory-patterns.md` - Pattern enforcement rules
- `references/planner-prompts.md` - Planner templates
- `references/common-patterns.md` - Reusable test patterns
- `scripts/calculate_criticality.py` - Automated scoring

---

## Related Skills

- `/test-fixer` - Diagnose and fix test failures
- `/test-coverage-retrofit` - Comprehensive coverage for legacy code
- `/tdd` - Test-driven development workflow
