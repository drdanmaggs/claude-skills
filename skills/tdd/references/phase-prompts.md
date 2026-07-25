# Phase Prompt Templates

Lean "phase brief" templates. The orchestrator fills in the `{variables}` and spawns the subagent. Subagents read their own context from disk — the orchestrator does NOT paste file contents into prompts.

**Principle:** Tell the subagent WHAT to do and WHERE to find context. The subagent reads the context itself.

---

## Session Constants

Discovered once during Setup (Stage 0a) and reused in every phase brief:

```
Plan file: {plan_file_path}            # e.g., "docs/plans/2026-02-07-category-search.md"
Test command: {test_command}           # e.g., "pnpm vitest run --reporter=verbose"
Test file pattern: {test_pattern}       # e.g., "colocated *.test.ts" or "tests/__tests__/"
Test helpers: {helper_paths}            # e.g., "tests/helpers/isolated-test-household.ts"
Standards file: {standards_path}        # this skill's bundled references/test-standards.md (absolute path resolved in Stage 0)
E2E test command: {e2e_test_command}   # e.g., "pnpm playwright test"
E2E test directory: {e2e_test_dir}     # e.g., "tests/e2e/"
Auth fixture: {auth_fixture_path}      # e.g., "tests/e2e/fixtures/auth-fixture.ts"
Acceptance test path: {acceptance_test_path}  # Set after Stage 0f. Empty if non-user-facing.
```

---

## Planning Phase: Plan subagent

### When

User chose "Auto-generate plan" from Stage 0-plan heuristic gate.

### Template

````
Task tool:
  subagent_type: "Plan"
  model: "sonnet"
  description: "Generate TDD implementation plan"
  prompt: |
    ## Task

    Create a Test-Driven Development implementation plan in Kent Beck format (incremental slices with checkbox tests).

    ## Feature/Bug Description

    {user_description}

    ## Required Format

    ```markdown
    # TDD Plan: {feature_name}

    ## Context
    [1-2 sentences: what problem this solves, why it matters]

    ## Architecture
    [2-3 sentences: chosen approach, critical files, integration points, key decisions]

    ## Session Constants
    Test command: {infer from project — look for package.json scripts, vitest.config.ts, etc.}
    Test file pattern: {infer from existing test files — colocated *.test.ts, tests/**/*.test.ts, etc.}
    Test helpers: {identify from tests/helpers/ or similar directories}

    ## Slice 1: {foundation — core logic/data model}
    Type: {unit|integration|e2e|pgtap} | Status: pending
    Files: {exact paths to test file and implementation file}

    - [ ] {specific test case — happy path, be concrete}
    - [ ] {edge case — empty input, null, undefined}
    - [ ] {edge case — invalid input, boundary conditions}
    - [ ] {error handling if applicable}

    ## Slice 2: {next layer — API endpoint, integration, UI}
    Type: {unit|integration|e2e|pgtap} | Status: pending
    Files: {exact paths}

    - [ ] {test case}
    - [ ] {test case}
    - [ ] {test case}

    [Continue with Slice 3, 4, etc. as complexity requires]
    ```

    ## Guidelines

    1. **Incremental slices**: Each slice builds on the previous. Order matters.
       - Slice 1: Core logic, data model, validation (unit tests typically)
       - Slice 2: Integration layer (API, database operations)
       - Slice 3: Edge cases, error handling, concurrency
       - Slice 4+: Additional features, optimizations

    2. **Slice count**: 3-6 slices typical
       - Simple features: 3 slices
       - Medium features: 4-5 slices
       - Complex features: 6+ slices

    3. **Test granularity**: Each checkbox is ONE test
       - Be specific: "should reject duplicate category name in same household"
       - Not vague: "test validation"

    4. **File paths**: Identify actual paths from the codebase
       - Use codebase search to find existing test directories
       - Follow project conventions (colocated vs tests/ directory)

    5. **Test types**:
       - unit: Pure functions, business logic, utilities
       - integration: Database operations, API routes, RLS policies
       - e2e: User workflows through real browser (Playwright)
       - pgtap: Database constraints, triggers, RLS (PostgreSQL)

    6. **Context to read before planning**:
       - this skill's bundled `references/test-standards.md` — testing patterns
       - Existing test files in the codebase — follow conventions
       - Related source files — understand current architecture
       - Database schema if relevant (supabase/migrations/)

    7. **Consider**:
       - RLS (Row Level Security) if using Supabase
       - Validation at boundaries (user input, API responses)
       - Concurrency and race conditions where applicable
       - Error states and failure modes
       - Edge cases: empty, null, duplicate, not-found, unauthorized

    ## Output

    Return the plan in the exact markdown format above. The TDD orchestrator will:
    1. Save it to docs/plans/YYYY-MM-DD-<feature-slug>.md
    2. Present to user for approval/edits
    3. Extract session constants
    4. Begin RED-GREEN-REFACTOR cycles
````

---

## Plan Review Phase: tdd-plan-reviewer

### When

After plan is created (via Plan Mode, auto-generation, or manual), before user approval.

### Purpose

Fresh eyes quality gate — catch TDD gaps, YAGNI violations, missing slices, architectural issues before RED-GREEN-REFACTOR begins.

### Template

````
Task tool:
  subagent_type: "tdd-plan-reviewer"
  model: "opus"
  description: "Review TDD plan for quality and completeness"
  prompt: |
    ## Task

    Review the TDD plan from a senior engineer lens. Evaluate testability, completeness, and architectural fit. Return findings before implementation begins.

    ## Files to Review

    Plan file: {plan_file_path}
    CLAUDE.md: .claude/CLAUDE.md (project standards and patterns)
    Related source files: {suggested_files_to_understand_existing_architecture}

    ## Evaluation Criteria

    For each plan slice, evaluate (use Sequential Thinking only for genuinely complex plans):

    1. **Testability** — Can you write a failing test for this slice? Is there a clear assertion that will pass/fail?
    2. **Slice Scope** — Is this a single logical unit or mixing multiple concerns?
    3. **Edge Cases** — What boundary conditions, error states, or data isolation scenarios are missing?
    4. **Duplication** — Does similar logic exist elsewhere that wasn't discovered?
    5. **Architecture Fit** — Does this align with the codebase's patterns, layers, conventions?
    6. **Data Isolation** — Are test fixtures clear? Cleanup explicit? Any CASCADE DELETE risks?
    7. **Abstraction Level** — Is the slice too vague ("add validation") or too granular?

    ## Return Format

    Use three categories:
    - 🔴 **Critical** — Blocks the plan (unfixable flaws)
    - 🟡 **Warning** — Requires decision (potential issues)
    - 🟢 **Note** — Improves clarity (suggestions)

    For each finding:
    - Which slice(s)
    - Specific concern (be concrete, not vague)
    - Recommended action or clarification needed

    ## Output

    Return exactly:

    ```
    ## Findings

    ### Slice: [name]
    - Category: 🔴 | 🟡 | 🟢
    - Concern: [specific issue]
    - Recommendation: [what to fix or clarify]

    ### Slice: [next]
    ...

    ## Overall Assessment
    - **Plan Quality**: Ready / Needs Changes / Blocked
    - **Key Gaps**: [list]
    - **Highest Risk Slices**: [which ones need scrutiny]

    ## Before Proceeding
    [Specific questions or changes needed before implementation]
    ```

    If no critical/warning issues: state "Plan is ready to implement" and list solid slices.
````

---

## Stage 0f: Acceptance Test (GOOS Outer Loop)

### When

After plan is approved, before inner loop begins.

**Orchestrator decision (use Sequential Thinking):** Does this feature add user-facing behaviour observable in a browser (new page, form, flow, navigation, toast, dialog)?
- YES → spawn acceptance test writer (template below)
- NO (pure utility/backend, no user journey) → skip 0f, set `Acceptance test path: none`

### Template

````
Task tool:
  subagent_type: "tdd-test-writer"
  model: "opus"
  description: "ACCEPTANCE TEST: {feature_name}"
  prompt: |
    Mode: acceptance
    Feature: {feature_name}
    Plan file: {plan_file_path}
    E2E test command: {e2e_test_command}
    E2E test directory: {e2e_test_dir}
    Auth fixture: {auth_fixture_path}
    Standards file: {standards_path}
    Write test to: {e2e_test_dir}/{feature-slug}.spec.ts

    Read the plan's Context and Architecture sections.
    Read the auth fixture to understand the fixture API.
    Read 1-2 existing E2E specs to learn naming and structure conventions.

    Write ONE Playwright acceptance test for the complete user journey.
    It must FAIL (feature doesn't exist yet).
````

### Post-0f (Orchestrator)

1. Verify test FAILS for expected reason (not syntax error)
2. Record `Acceptance test path` in session constants
3. Commit: `test: add acceptance test for {feature_name}`
4. **Do NOT run this test again during inner loop cycles** — only run at outer loop exit
5. Proceed to inner loop (Stage 1: TIDY FIRST)

---

## TIDY FIRST Phase: tdd-refactorer (prep)

**When:** Before RED, **only if the Opus orchestrator judges the code the next test will touch needs structural prep** — a long/tangled function about to grow, poor naming that obscures where the new code goes, or duplication the new code would amplify. For new code or already-clean targets, **skip the spawn entirely** — don't pay an agent launch to be told "SKIP".

**Purpose:** Create space for new behavior before writing the test (Kent Beck's "Tidy First?" pattern), when there's genuinely something to tidy.

````
Task tool:
  subagent_type: "tdd-refactorer"
  model: "haiku"
  description: "PREP: {next_test_description}"
  prompt: |
    Mode: PREP
    Feature: {feature_name}
    Next test: {next_test_description}
    Test command: {test_command}
    Files to read: {impl_file_paths}
````

---

## RED Phase: tdd-test-writer

### Pre-RED check (Orchestrator)

Confirm two things inline before spawning tdd-test-writer — Opus does this in a sentence, no formal thinking pass:

1. The next unchecked plan item is ONE specific test.
2. The brief asks for EXACTLY ONE test — never "tests for these rules" (that implies batching).

Sequential Thinking is available but **not required** here — reach for it only if the next test is genuinely ambiguous (unclear boundary, multiple plausible interpretations). The ONE TEST gate is still hard; verifying it just doesn't warrant a ritual.

### Template

```
Task tool:
  subagent_type: "tdd-test-writer"
  model: "sonnet"
  description: "RED: {test_description}"
  prompt: |
    Mode: unit/integration  # Always "unit/integration" in inner loop. Acceptance test was written once in Stage 0f.
    Feature: {feature_name}
    Slice: {slice_number} — {slice_description}
    Test type: {unit|integration|e2e|pgtap}
    Test command: {test_command}
    Your test: "{next_unchecked_test_description}"
    Files to read: {plan_file_path}, {standards_path}, {existing_test_files}, {test_helpers}, {source_files}
    Already tested: {checked_list or "Nothing yet — this is the first test"}
```

### Post-RED Verification (Orchestrator)

After tdd-test-writer returns, the orchestrator MUST verify test count before checking test failure:

```
1. Read the test file that was modified
2. Count how many test cases were added in this cycle
   - Look for new `it()`, `test()`, or `SELECT plan()` (pgTAP) calls
   - Compare against plan file — only ONE test should be newly checked
3. If count > 1:
   - **HARD GATE FAILURE**
   - Message: "tdd-test-writer violated the ONE TEST constraint. It added {N} tests instead of 1. This breaks TDD feedback loops."
   - Undo the changes (git restore or manual edit)
   - Respawn tdd-test-writer with even stronger emphasis on the constraint
4. If count == 1:
   - Proceed to verify test failure (GATE 2)
```

**Example respawn prompt after batch violation:**

```
CRITICAL: Your previous attempt added {N} tests instead of ONE.

This is a HARD CONSTRAINT. TDD requires ONE test at a time.

You must write EXACTLY ONE test for: "{specific_test_description}"

Do NOT write any other tests, even if they're related or simple.
```

---

## GREEN Phase: tdd-implementer

```
Task tool:
  subagent_type: "tdd-implementer"
  model: "haiku"
  description: "GREEN: {test_description}"
  prompt: |
    Feature: {feature_name}
    Test command: {test_command}
    Failing test: {test_file_path}
    Failure: {one_line_failure_summary}
    Files to read: {test_file_path}, {source_files}, {plan_file_path} (read-only)
```

---

## REFACTOR Phase: tdd-refactorer

**When:** After GREEN, **only if the orchestrator sees something worth cleaning** — duplication, a complex conditional, unclear naming, or a GREEN diff larger than ~10 lines. Trivial diffs: skip the spawn. A full-slice refactor still runs once at each slice boundary as the safety net. Bump `model` to `sonnet` for a substantial multi-file refactor; Haiku is fine for localized cleanups.

````
Task tool:
  subagent_type: "tdd-refactorer"
  model: "haiku"
  description: "REFACTOR: {feature_name}"
  prompt: |
    Mode: REFACTOR
    Feature: {feature_name}
    Test command: {test_command}
    Files to read: {test_file_paths}, {impl_file_paths}
````

---

## Regression Analysis Phase

**Trigger:** User accepts at completion gate (Stage 7) — applies to both feature and bug-fix modes

**Invocation:**

```
Task tool:
  subagent_type: "general-purpose"
  model: "opus"
  description: "Analyze for test coverage gaps and edge cases"
  prompt: |
    You are performing regression analysis at the end of a TDD workflow.

    Read this skill's bundled `references/regression-analysis.md` for full methodology.

    ## Context
    Feature/Bug: {description from plan or diagnosis}
    Files modified: {list of files changed during this TDD session}
    Tests written: {list of test files created/modified}

    ## Your Task
    1. Analyze the change for patterns, edge cases, and integration risks (use Sequential Thinking if the change is complex or the pattern space is large)
    2. Search codebase (Grep/Read) to verify findings
    3. Generate test recommendations using the priority rubric
    4. Return findings in the mandatory output format (see regression-analysis.md)

    Focus on what could go wrong, not what already works.
```

**After analysis returns findings:**

1. **Auto-filter using QUICK WIN check** (spawn general-purpose subagent per finding, max 7 concurrent):

   **Subagent brief:**

   ```
   Evaluate this regression finding using QUICK WIN criteria.

   Finding: {description, location, risk, priority}

   QUICK WIN check (ALL THREE must be true):
   ✓ Predictable cost - < 5 min, specific change, no cascading effects
   ✓ Real benefit - Fixes actual weakness (not speculative "might break")
   ✓ Confident correctness - Familiar pattern, testable, won't create new problems

   Steps:
   1. Read the flagged file and surrounding context
   2. Verify: is this an ACTUAL bug/gap or speculative concern?
      - Pattern duplication (same bug elsewhere): likely ACTUAL
      - Future brittleness (might break if...): likely SPECULATIVE
   3. Evaluate QUICK WIN criteria:
      - Predictable cost: Can we copy an existing test pattern? Is scope clear?
      - Real benefit: Does code exist? Is it actively used? Is failure likely?
      - Confident correctness: Do we know the fix? Is pattern proven?
   4. If confidence 50-79%: use Sequential Thinking to reason deeper
   5. Return: {category: "QUICK WIN" | "SKIP", confidence: 0-100, reasoning}
   ```

   **Categorization:**
   - **QUICK WIN**: Implement now (e.g., same bug pattern exists in ComponentB, we just fixed it in ComponentA)
   - **SKIP**: Defer to GitHub issue (e.g., speculative "add comprehensive error handling", unpredictable scope)

2. **Process QUICK WIN findings automatically:**
   - Spawn tdd-test-writer subagent for each QUICK WIN
   - Write tests using standard TDD workflow
   - Commit separately: `test: regression coverage for [pattern class]`

3. **Process SKIP findings automatically:**
   - Create GitHub issue for each
   - Title: `[Regression] {finding description}`
   - Body: Include location, risk, test type, reasoning for deferral
   - Labels: "regression-analysis", "test-gap"
   - Link to original PR/commit

**No user prompt** - automatic YAGNI-compliant filtering prevents scope creep while catching real bugs.

---

## Warm Loop Optimization

After 3+ successful RED-GREEN cycles without issues, the orchestrator should:

- Reduce between-phase commentary (the pattern is working)
- Spawn the next subagent immediately after gate passes
- Trust the process — don't re-explain the methodology each cycle
