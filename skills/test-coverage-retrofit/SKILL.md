---
name: test-coverage-retrofit
description: Systematically retrofit unit tests to existing codebases using coverage-driven parallel test writing. Discovers codebase patterns (Sonnet), plans tests (Sonnet), writes tests (Haiku with codebase-specific guidance), and targets 95% overall coverage. Use when retrofitting tests to legacy code, improving test coverage, or systematically adding missing tests. Auto-triggers on "add test coverage", "retrofit tests", "improve coverage", "get to 95% coverage", "add missing tests".
---

# Test Coverage Retrofit

Coverage-driven test retrofitting with intelligent pattern discovery and parallel test generation. Target: 95% overall coverage with high-quality, architecture-compatible, non-flaky tests.

**Key features:**

- Sonnet-powered codebase pattern discovery (mocking philosophy, type safety, integration patterns)
- Sonnet planners for context-aware test case design
- Sonnet writers with enhanced guidance (architecture-aware, quality-focused)

## When to Use

- Retrofitting tests to legacy/untested code
- Systematically improving coverage from <95%
- Adding tests to specific directories (lib/, app/, etc.)

## When NOT to Use

- Active feature development → Use `/tdd` instead
- Fixing broken tests → Use `/test-fixer` instead
- Coverage already >95% → YAGNI, focus on new features

---

## Workflow Overview

```
1. Ask user: What test type to focus on? (unit/integration/e2e/all)
   ↓
2. Generate coverage report (JSON + HTML)
   ↓
3. Parse coverage, CLASSIFY by test type based on user preference
   ↓
4. Create tracking document with PHASE 1 (unit) and PHASE 2 (integration)
   ↓
5. PHASE 1 LOOP (skip if user selected integration/e2e only):
   ├─ a. Spawn Sonnet planner agents (parallel, one per file)
   ├─ b. Spawn Sonnet test-writer agents (lighter verification, 1-2 runs)
   ├─ c. Check coverage: >= 95%? STOP ✅ : Continue
   └─ d. Commit folder's tests
   ↓
6. Early stop check: If Phase 1 >= 95%, skip Phase 2 entirely ✅
   ↓ (only if < 95% and user didn't select unit only)
7. PHASE 2 LOOP (skip if user selected unit only):
   ├─ a. Spawn Sonnet planner agents (parallel, one per file)
   ├─ b. Spawn Sonnet test-writer agents (STRICT verification, 3 runs required)
   ├─ c. If user selected e2e: Filter to only E2E test files
   ├─ d. Check coverage: >= 95%? STOP ✅ : Continue
   └─ e. Commit folder's tests
   ↓
8. Final summary with phase breakdown
```

**Key insights:**

- **User-controlled test type selection** = Focus on unit, integration, e2e, or all types per session
- **Two-phase approach** = Unit tests first (fast wins), integration only if needed (when "all" selected)
- **Test type classification** = Different verification levels prevent flakiness
- **Early stopping** = Phase 1 alone may reach 95%, skip Phase 2
- **Parallel within folder** = fast execution (100 agents at a time is fine)
- **One writer per file** = no conflicts, safe parallel test execution

---

## Stage 0: Setup & Check for Existing Tracker

### 0. Create TodoWrite Task List

**IMMEDIATELY** create todos using TodoWrite tool:

```markdown
1. [in_progress] Stage 0: Check for existing tracker
2. [pending] Stage 1: Generate coverage & classify by test type
3. [pending] Stage 2a: Phase 1 - Unit tests (target 95%)
4. [pending] Stage 2b: Phase 2 - Integration tests (only if Phase 1 < 95%)
5. [pending] Stage 3: Completion & summary
```

Update status as you progress.

### 1. Check for Existing Tracker (Like TDD 0-check)

```bash
ls .claude/docs/test-coverage-tracker.md
```

**If tracker exists:**

- Read it and count unchecked items: `grep -c "^- \[ \]" .claude/docs/test-coverage-tracker.md`
- If unchecked items > 0: **Automatically resume** → Skip to Stage 2 (Process Folders)
- If unchecked items = 0: Delete tracker, continue to Stage 1 (regenerate coverage)

**If tracker doesn't exist:** Continue to Stage 1

### 2. Git Safety & Auto-Branch

```bash
branch=$(git branch --show-current)
if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  # Auto-create branch
  new_branch="test/coverage-retrofit-$(date +%s)"
  git checkout -b "$new_branch"
  echo "✓ Created branch: $new_branch"
fi
```

### 3. Detect Package Manager & Verify Vitest

```bash
# Detect package manager
if [ -f "pnpm-lock.yaml" ]; then
  PKG_MANAGER="pnpm"
elif [ -f "yarn.lock" ]; then
  PKG_MANAGER="yarn"
else
  PKG_MANAGER="npm"
fi

$PKG_MANAGER test -- --help
```

If test command doesn't exist, STOP and inform user.

**Throughout this skill, use `$PKG_MANAGER` for all test commands.**

### 4. Run Baseline Tests

```bash
$PKG_MANAGER test
```

**If tests pass:** Continue to Step 5.

**If tests fail:** Offer to skip failing tests and proceed.

#### Handling Failing Tests

When baseline tests fail:

1. **Parse test output** to identify failing test file(s):

   ```bash
   # Vitest output shows failing test paths
   # Example: "FAIL app/lib/utils.test.ts"
   ```

2. **Present options to user:**

   ```
   ⚠️  Some tests are failing:

   Failing tests:
   - app/lib/utils.test.ts (2 tests failed)
   - app/lib/helpers.test.ts (1 test failed)

   **Options:**
   1. Skip these tests and generate coverage for remaining code
   2. Exit and fix tests first (use /test-fixer)

   Recommendation: Skip if failures seem unrelated to coverage scope.
   ```

3. **If user chooses to skip:**
   - Store failing test paths in variable: `SKIP_TESTS="utils.test.ts|helpers.test.ts"`
   - Continue to coverage generation (Step 5) with exclusions
   - Log skipped tests for summary

4. **If user chooses to exit:**

   ```
   Exiting test-coverage-retrofit.

   Fix failing tests with /test-fixer, then re-run this skill.
   ```

**Coverage generation with exclusions** (used in Stage 1.1):

```bash
# Pass skip pattern to coverage script
bash <skill-path>/scripts/generate_coverage.sh lib/ "$SKIP_TESTS"
```

The script will use `--exclude` patterns to skip failing test files during coverage.

### 5. Detect Scope Automatically

```bash
# Auto-detect directories with <95% coverage
# Priority order: lib/, src/, app/
for dir in lib src app; do
  if [ -d "$dir" ]; then
    SCOPE="$dir/"
    echo "📂 Selected scope: $SCOPE (auto-detected)"
    break
  fi
done

# Fallback: entire codebase
if [ -z "$SCOPE" ]; then
  SCOPE="."
  echo "📂 Selected scope: entire codebase"
fi
```

**Autonomous operation:** No user input required. Proceeds automatically with detected scope.

### 5.5. Ask User for Test Type Preference

**Use AskUserQuestion to let user choose test type scope for this session:**

```json
{
  "questions": [
    {
      "question": "What type of tests do you want to work on in this session?",
      "header": "Test Type",
      "multiSelect": false,
      "options": [
        {
          "label": "Unit tests only (Recommended)",
          "description": "Pure functions, utilities, business logic. Fast tests with no I/O. Good starting point for legacy code."
        },
        {
          "label": "Integration tests only",
          "description": "Database operations, API calls, Supabase. Tests with external dependencies. Critical paths."
        },
        {
          "label": "E2E tests only",
          "description": "Full browser automation, user journeys. Playwright tests for complete user flows."
        },
        {
          "label": "All types",
          "description": "Run unit, integration, and E2E phases sequentially. Comprehensive coverage (current default)."
        }
      ]
    }
  ]
}
```

**Store result in `TEST_TYPE_PREFERENCE` variable:**

- "Unit tests only (Recommended)" → `TEST_TYPE_PREFERENCE="unit"`
- "Integration tests only" → `TEST_TYPE_PREFERENCE="integration"`
- "E2E tests only" → `TEST_TYPE_PREFERENCE="e2e"`
- "All types" → `TEST_TYPE_PREFERENCE="all"`

**This preference will:**

- Control which phases execute (Phase 1, Phase 2, or both)
- Pass to `parse_coverage.py` to filter/classify files appropriately
- Determine verification strictness (unit: 1-2 runs, integration: 3 runs, E2E: specific patterns)

### 6. Discover Session Constants (Like TDD Stage 0a)

**Purpose:** Discover project-specific test patterns ONCE, then reuse in every planner/test-writer agent prompt.

Spawn **Explore agent (Sonnet)** to discover:

```
Task tool with:
- subagent_type: "Explore"
- model: "sonnet"
- description: "Discover test patterns"
- prompt: (see below)
```

**Why Sonnet not Haiku?** Discovery happens ONCE and sets the foundation for hundreds of generated tests. Sonnet is significantly better at:

- Understanding complex CLAUDE.md rules
- Extracting nuanced patterns from existing tests
- Identifying architectural conventions (integration vs mocks)
- Cost: ~$0.10 vs $0.01, but prevents regenerating thousands of incompatible tests

**Explore agent prompt:**

```
Discover project-specific test patterns and conventions for this codebase.

**Your task:**
1. Find test command format
2. Identify test file pattern (colocated vs __tests__)
3. Locate test helpers directory and key helpers
4. Discover mocking patterns (what's OK to mock, what's not)
5. Discover type safety requirements and banned patterns
6. Extract integration test patterns from existing tests
7. Check for test standards/patterns documentation
8. Return findings as structured data

**Search strategy:**

1. **Test command:**
   - Read package.json scripts section
   - Look for "test" script
   - Note package manager: $PKG_MANAGER
   - Format: "$PKG_MANAGER test -- [additional flags]"

2. **Test file pattern:**
   - Search for existing test files: `**/*.test.ts` OR `tests/__tests__/**/*.ts`
   - Check vitest.config.ts for include patterns
   - Determine: colocated (next to source) OR centralized (__tests__/)

3. **Test helpers:**
   - Search for: `tests/helpers/**/*.ts` OR `__tests__/helpers/**/*.ts`
   - Key helpers to find:
     - createIsolatedTestHousehold (test data isolation)
     - testName() (test naming)
     - Any setup/cleanup utilities
   - Note file paths for import
   - Read helper implementations to understand usage

4. **Mocking patterns (CRITICAL - prevents architectural mismatches):**
   - Read `~/.claude/rules/testing-server-actions.md` for mock guidance
   - Grep existing test files for `vi.mock()` calls
   - Identify:
     - Which services are mocked (external APIs only?)
     - Which services are NOT mocked (internal wrappers, Supabase client?)
     - Pattern: Integration tests with real clients vs unit tests with mocks
   - Check for "REMOVE mocks" or "KEEP mocks" guidance in rules

5. **Type safety requirements (CRITICAL - prevents type errors):**
   - Read eslint.config.* for:
     - `@typescript-eslint/no-explicit-any` (error/warn/off?)
     - `@typescript-eslint/ban-ts-comment` (bans @ts-ignore, @ts-nocheck)
     - `@typescript-eslint/no-unsafe-*` rules
   - Read tsconfig.json for `strict: true`
   - Read `~/.claude/rules/code-quality.md` for type standards
   - Check existing test files for:
     - Use of `unknown` instead of `any`
     - Presence of banned escape hatches (@ts-nocheck, @ts-ignore)
     - Type import patterns

6. **Integration test patterns:**
   - Find 1-2 existing integration test files (grep for "createIsolatedTestHousehold")
   - Extract patterns:
     - How is Supabase client created? (SERVICE_ROLE_KEY?)
     - How are test households created and cleaned up?
     - How are IDs tracked for cleanup?
     - What's the afterAll cleanup pattern?
   - Example code snippet for reference

7. **Test standards:**
   - Check: `~/.claude/rules/` for test-related rules
   - Check: `.claude/skills/tdd/references/test-standards.md`
   - Check: project README or docs/ for test conventions

8. **Mock safety patterns (Anti-flakiness):**
   - Read `~/.claude/rules/testing.md` (Vitest/Integration section) for safe patterns
   - Check existing tests for:
     - Use of `vi.mock()` vs `vi.spyOn()` (ratio/preference)
     - `vi.clearAllMocks()` usage in beforeEach/afterEach
     - Check `vitest.config.ts` for `restoreMocks`/`mockReset` settings
   - Identify preferred mocking API for this codebase

9. **Async timing patterns (Anti-flakiness):**
   - Read `~/.claude/rules/testing.md` (Playwright/E2E section) for best practices
   - Check existing tests for:
     - `waitFor`/`findBy` usage patterns
     - Any `waitForTimeout` anti-patterns (grep for "waitForTimeout")
   - E2E tests: Check for hydration gap handling patterns

**Output format - Return as structured JSON:**

{
  "test_command": "pnpm test -- --reporter=verbose",
  "test_file_pattern": "colocated" | "centralized",
  "test_file_suffix": ".test.ts" | ".spec.ts",
  "test_helpers": {
    "directory": "tests/helpers",
    "key_helpers": [
      {
        "name": "createIsolatedTestHousehold",
        "path": "tests/helpers/isolated-test-household.ts",
        "purpose": "Creates isolated test data with cleanup",
        "usage_example": "household = await createIsolatedTestHousehold(supabase);"
      },
      {
        "name": "testName",
        "path": "tests/helpers/test-name.ts",
        "purpose": "Generates prefixed test names for cleanup",
        "usage_example": "const name = testName('Recipe');"
      }
    ]
  },
  "mocking_patterns": {
    "philosophy": "integration_over_mocks" | "unit_with_mocks",
    "external_services_mocked": ["ai", "@langfuse/*"],
    "internal_services_never_mock": ["@/lib/supabase/server", "@/lib/dal", "next/cache"],
    "reasoning": "Extract logic to logic.ts files, test logic with real Supabase client",
    "discovered_from": "~/.claude/rules/testing-server-actions.md"
  },
  "type_safety": {
    "any_type_banned": true | false,
    "escape_hatches_banned": ["@ts-nocheck", "@ts-ignore", "@ts-expect-error"],
    "use_unknown_instead": true,
    "strict_mode": true,
    "eslint_rules": [
      "@typescript-eslint/no-explicit-any: error",
      "@typescript-eslint/ban-ts-comment: error"
    ],
    "common_type_imports": [
      "import type { SupabaseClient } from '@supabase/supabase-js';",
      "import type { Database } from '@/types/supabase';"
    ],
    "discovered_from": "eslint.config.*, tsconfig.json, ~/.claude/rules/code-quality.md"
  },
  "integration_test_pattern": {
    "uses_isolated_households": true,
    "supabase_client_creation": "createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!)",
    "cleanup_pattern": "Track IDs in arrays, delete in afterAll (children before parents)",
    "example_structure": "
import { createIsolatedTestHousehold, cleanupIsolatedTestHousehold } from '@/tests/helpers/isolated-test-household';

describe('Feature tests', () => {
  let supabase: SupabaseClient;
  let household: IsolatedTestHousehold;
  let createdIds: string[] = [];

  beforeAll(async () => {
    supabase = createClient(URL, SERVICE_ROLE_KEY);
    household = await createIsolatedTestHousehold(supabase);
  });

  afterAll(async () => {
    await supabase.from('table').delete().in('id', createdIds);
    await cleanupIsolatedTestHousehold(supabase, household.householdId);
  });

  it('test case', async () => {
    const result = await logic(supabase, household.householdId);
    createdIds.push(result.id);
    expect(result.success).toBe(true);
  });
});
    "
  },
  "test_standards": {
    "rules": [
      "~/.claude/rules/testing.md",
      "~/.claude/rules/code-quality.md"
    ],
    "project_conventions": "Colocated tests, integration over mocks, real Supabase clients"
  },
  "imports_commonly_needed": [
    "import { describe, it, expect, beforeAll, afterAll } from 'vitest';",
    "import { createClient } from '@supabase/supabase-js';",
    "import type { SupabaseClient } from '@supabase/supabase-js';"
  ],
  "mock_safety": {
    "config_has_restoreMocks": true | false,
    "preferred_mocking_api": "vi.spyOn" | "vi.mock",
    "uses_clearAllMocks": true | false,
    "discovered_from": "vitest.config.ts + existing tests"
  },
  "async_patterns": {
    "uses_findBy": true | false,
    "has_waitForTimeout_antipattern": false,
    "e2e_hydration_handling": "hydration marker" | "retry pattern" | "none",
    "discovered_from": "existing test files"
  }
}

**IMPORTANT:**
- Explore the actual codebase - don't assume
- If helpers don't exist, return empty arrays
- If standards don't exist, note that
- Read at least 1 existing integration test to extract real patterns
- Identify architectural philosophy (mocks vs real clients) from rules and existing tests
- Return JSON only
```

**After Explore agent completes:**

1. Parse JSON output
2. Store in internal state as `SESSION_CONSTANTS`
3. Include relevant sections in EVERY planner and test-writer prompt going forward

**Example usage in subsequent prompts:**

````
**Session constants (project-specific patterns discovered from codebase):**

**Test execution:**
- Command: pnpm test -- --reporter=verbose
- Pattern: Colocated (.test.ts next to source files)

**Test helpers available:**
- createIsolatedTestHousehold: tests/helpers/isolated-test-household.ts
  Usage: `household = await createIsolatedTestHousehold(supabase);`
- testName: tests/helpers/test-name.ts
  Usage: `const name = testName('Recipe');`

**Mocking philosophy (CRITICAL):**
- Architecture: Integration tests with real clients preferred
- NEVER mock: @/lib/supabase/server, @/lib/dal, next/cache
- OK to mock: External APIs (ai, @langfuse/*)
- Reasoning: Extract logic to logic.ts, test logic with real Supabase client
- Source: ~/.claude/rules/testing-server-actions.md

**Type safety (CRITICAL - WILL FAIL CI IF VIOLATED):**
- any type: BANNED - use specific types or unknown with validation
- Escape hatches BANNED: @ts-nocheck, @ts-ignore, @ts-expect-error
- ESLint rules enforced: @typescript-eslint/no-explicit-any (error)
- If type unknown: Use `unknown` and add runtime validation
- Never use TypeScript escape hatches to silence errors

**Integration test pattern:**
```typescript
import { createIsolatedTestHousehold, cleanupIsolatedTestHousehold } from '@/tests/helpers/isolated-test-household';
import type { SupabaseClient } from '@supabase/supabase-js';

describe('Feature tests', () => {
  let supabase: SupabaseClient;
  let household: IsolatedTestHousehold;
  let createdIds: string[] = [];

  beforeAll(async () => {
    supabase = createClient(URL, SERVICE_ROLE_KEY);
    household = await createIsolatedTestHousehold(supabase);
  });

  afterAll(async () => {
    // Delete children before parents (FK order)
    await supabase.from('table').delete().in('id', createdIds);
    await cleanupIsolatedTestHousehold(supabase, household.householdId);
  });

  it('test case', async () => {
    const result = await logic(supabase, household.householdId);
    createdIds.push(result.id); // Track for cleanup
    expect(result.success).toBe(true);
  });
});
````

**Common imports:**

```typescript
import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { createClient } from "@supabase/supabase-js";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  createIsolatedTestHousehold,
  cleanupIsolatedTestHousehold,
} from "@/tests/helpers/isolated-test-household";
```

**Standards to follow:**

- ~/.claude/rules/testing.md
- ~/.claude/rules/code-quality.md

````

---

## Stage 1: Generate Coverage & Classify by Test Type

**Update TodoWrite:** Mark Stage 0 `completed`, Stage 1 `in_progress`.

**Goal:** Generate coverage report, classify files as unit/integration, create two-phase tracker.

### 1.1 Generate Coverage Report

```bash
cd <project-root>
# If SKIP_TESTS was set in Stage 0.4, pass it here
bash <skill-path>/scripts/generate_coverage.sh lib/ "$SKIP_TESTS"
````

**Note:** If Stage 0 identified failing tests and user chose to skip them, `$SKIP_TESTS` contains the pipe-separated list (e.g., `"utils.test.ts|helpers.test.ts"`). Otherwise it's empty and all tests run.

Generates:

- `./coverage/coverage-final.json` (for parsing)
- `./coverage/index.html` (for human review)
- Coverage excludes any skipped failing tests

**Early Exit Check:**

```bash
# Check if already at target
bash <skill-path>/scripts/verify_target.sh 95 lib/
```

**If coverage >= 95%:**

```
✅ Coverage already meets target!

Current coverage: 83.2%
Target: 95%

No test retrofitting needed. Exiting gracefully.
```

**Exit immediately** - mark all stages complete, skip to Stage 3 summary.

**If coverage < 95%:** Continue to 1.2 (Parse Coverage).

### 1.2 Parse Coverage & Classify by Test Type

```bash
python3 <skill-path>/scripts/parse_coverage.py \
  ./coverage/coverage-final.json \
  lib/ \
  --test-type "$TEST_TYPE_PREFERENCE" \
  > coverage-parsed.json
```

**Classification based on TEST_TYPE_PREFERENCE:**

- `unit`: Classifies ALL files as unit tests (force unit)
- `integration`: Classifies ALL files as integration tests (force integration)
- `e2e`: Filters to only E2E test files (tests/e2e/ directory or page routes)
- `all`: Auto-classifies each file based on patterns (default behavior):
  - **Unit**: logic.ts files, utils/, helpers/, files with vi.mock()
  - **Integration**: actions.ts files, files with createClient/createIsolatedTestHousehold

Groups files by test type, then folder, prioritizes by:

- Folder importance (auth, api, core logic)
- Average coverage %
- Total impact (uncovered lines)

### 1.3 Create Two-Phase Tracker

```bash
python3 <skill-path>/scripts/create_tracker.py \
  coverage-parsed.json \
  .claude/docs/test-coverage-tracker.md \
  95\
  lib/
```

**New in v2:** Creates tracker organized BY TEST TYPE, then folder:

```markdown
# Test Coverage Retrofit Tracker

**Target:** 95% overall coverage
**Current:** 45.3%
**Scope:** lib/

**Strategy:** Two-phase approach

1. Phase 1: Unit tests → 95% (fast wins, lighter verification)
2. Phase 2: Integration tests (only if needed)

**Early stopping:** If Phase 1 reaches 95%, Phase 2 is skipped.

---

## PHASE 1: UNIT TESTS (Target: 95%)

Unit tests are faster to write and less flaky. We process these first.

### Folder: lib/utils/ (55% avg coverage)

- [ ] `lib/utils/validation.ts` — 55% coverage, 30 uncovered lines
- [ ] `lib/utils/formatters.ts` — 60% coverage, 20 uncovered lines

### Folder: lib/helpers/

- [ ] `lib/helpers/dates.ts` — 30% coverage, 45 uncovered lines

---

## PHASE 2: INTEGRATION TESTS (Only if Phase 1 < 95%)

Integration tests require real DB, cleanup, and multi-run verification.

### Folder: lib/auth/ (12% avg coverage)

- [ ] `lib/auth/logic.ts` — 15% coverage, 102 uncovered lines
- [ ] `lib/auth/session.ts` — 8% coverage, 67 uncovered lines

### Folder: lib/api/

- [ ] `lib/api/users-logic.ts` — 0% coverage, 85 uncovered lines
```

### 1.4 Show Summary

```
📊 Coverage Analysis Complete

Current: 45.3% → Target: 95%

**PHASE 1: UNIT TESTS**
Folders to process:
1. lib/utils/ (55% coverage) — 2 files
2. lib/helpers/ (30% coverage) — 1 file

**PHASE 2: INTEGRATION TESTS** (only if Phase 1 < 95%)
Folders to process:
1. lib/auth/ (12% coverage) — 2 files
2. lib/api/ (0% coverage) — 1 file

Tracker: .claude/docs/test-coverage-tracker.md

Starting Phase 1 (Unit Tests)...
```

**Update TodoWrite:** Mark Stage 1 `completed`, Stage 2a `in_progress`.

---

## Stage 2a: PHASE 1 - Unit Tests

**Skip this stage if TEST_TYPE_PREFERENCE is "integration" or "e2e"**

**Goal:** Process ALL Phase 1 folders, write all unit tests, THEN check coverage once.

**This phase processes ALL unit test folders in sequence. Coverage is checked ONCE at the end, not after each folder.**

**Test type filtering:**

- If `TEST_TYPE_PREFERENCE="unit"`: Process Phase 1 normally (all files classified as unit)
- If `TEST_TYPE_PREFERENCE="integration"`: **Skip to Stage 2b (Phase 2)**
- If `TEST_TYPE_PREFERENCE="e2e"`: **Skip to Stage 2b (Phase 2 will filter to E2E tests)**
- If `TEST_TYPE_PREFERENCE="all"`: Process Phase 1 normally (auto-classification)

### 2a.1 Find All Phase 1 Folders

Read tracker and extract ALL folders under "## PHASE 1: UNIT TESTS" section:

```bash
# Extract all Phase 1 folders
sed -n '/^## PHASE 1/,/^## PHASE 2/p' .claude/docs/test-coverage-tracker.md | grep "^### Folder"
```

Example output:

```
### Folder: lib/utils/ (55% avg coverage)
### Folder: lib/helpers/ (30% avg coverage)
### Folder: lib/auth/ (12% avg coverage)
```

Store folder list, process each folder in sequence (steps 2a.2-2a.4).

### 2a.2 Process Each Folder (Loop)

**For EACH folder in Phase 1, do steps 2a.3-2a.5**

Repeat until all Phase 1 folders are processed, THEN check coverage once.

### 2a.3 Plan Tests for Current Folder (Sonnet Planners)

For files in THIS folder only, spawn **Sonnet planner agents in parallel**:

```
Task tool with:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Plan tests for [filename]"
- prompt: (see below)
```

**Planner prompt template:**

````
Plan test cases for this file to improve coverage.

**File classification:** UNIT TEST (Phase 1)

**Test type guidance:**
- Lighter verification approach
- Mocking encouraged (vi.mock for external dependencies)
- No real database required
- Focus on pure function behavior, edge cases, error handling

**Session constants (project-specific patterns):**
[Include relevant session constants from Stage 0.6]
- Test command: [test_command from SESSION_CONSTANTS]
- Test pattern: [test_file_pattern] ([test_file_suffix] files)
- Test helpers: [list key helpers with import paths]
- Standards: [list applicable rules/docs]
- Common imports:
  ```typescript
  [imports_commonly_needed from SESSION_CONSTANTS]
````

**Your task:**

1. Read source file: [file_path]
2. Check existing test file (if any) for project patterns
3. Identify file type and relevant patterns
4. Identify uncovered functions (see list below)
5. Plan specific test cases for each function
6. RETURN test case list + relevant patterns (do NOT edit tracker - orchestrator will update it)

**Source file:** [file_path]

**Uncovered functions:**
[List from tracker]

**Output format - Return as structured JSON:**

{
"file_path": "[file_path]",
"file_type": "server_action | business_logic | api_route | utility | component",
"relevant_patterns": [
"server-actions-pattern",
"test-data-isolation",
"self-cleaning-tests"
],
"test_cases": [
"Test: [function_name] handles valid input",
"Test: [function_name] rejects invalid input",
"Test: [function_name] handles edge case X"
],
"setup_notes": "Uses Supabase client, needs isolated household, etc."
}

**Pattern identification guide:**

- **server_action** (file ends with `actions.ts`) → Extract logic to `logic.ts`, test logic not wrapper
- **business_logic** → Test behavior, mock external APIs only
- **api_route** → Test request handling, validation, error responses
- **utility** → Test transformations, edge cases, errors
- **component** → Test user interactions, state changes, rendering

**Test patterns:** Read [skill-path]/references/test-patterns.md to identify which patterns apply.

**IMPORTANT:** Return JSON only. Orchestrator will parse and update tracker to prevent write conflicts.

````

**Spawn ONE planner per file in folder** (parallel execution).

**After all planners complete:** Orchestrator collects outputs and updates tracker once.

### 2a.4 Write Tests for Current Folder (Haiku Test Writers)

**Orchestrator (you):**
1. Wait for all planners to complete
2. Parse JSON outputs from each planner
3. Store pattern mappings for each file (pass to Haiku writers)
4. Update tracker once with all test cases (avoids write conflicts)

**Store pattern data:**
```typescript
// Example internal state
const filePatterns = {
  "lib/auth/logic.ts": {
    file_type: "business_logic",
    relevant_patterns: ["test-data-isolation", "self-cleaning-tests"],
    setup_notes: "Uses Supabase client, needs isolated household"
  }
}
````

After update, tracker looks like:

```markdown
## Folder 1: lib/auth/ (12% coverage)

- [ ] `lib/auth/logic.ts` — 15% coverage
  - [ ] Test: loginUser handles valid credentials
  - [ ] Test: loginUser rejects invalid email
  - [ ] Test: validateToken checks JWT signature
```

Show brief update: "✅ Test plan complete for lib/auth/ - 8 test cases identified"

### 2.4 Write Tests (Sonnet Test Writers)

For each FILE (not test case), spawn **Sonnet test-writer agents in parallel**:

```
Task tool with:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Write tests for [filename]"
- prompt: (see below)
```

**Writer prompt template:**

````
Write ALL test cases for this file.

**Source file:** [file_path]
**Test file:** [test_file_path]
**File type:** [file_type from planner]

**Test cases to write:**
[List all test cases from tracker for this file]

**Relevant patterns for THIS file:**
[relevant_patterns from planner - e.g., "server-actions-pattern", "test-data-isolation"]

**Setup guidance:**
[setup_notes from planner]

**Session constants (project-specific patterns discovered from codebase):**
[Include from Stage 0.6 SESSION_CONSTANTS]

**Test execution:**
- Command: [test_command]
- Pattern: [test_file_pattern] ([test_file_suffix] files)

**Test helpers available:**
[For each helper:]
- [name]: [path]
  Usage: [usage_example]

**Mocking philosophy (CRITICAL):**
- NEVER mock: [internal_services_never_mock from SESSION_CONSTANTS]
- OK to mock: [external_services_mocked from SESSION_CONSTANTS]
- Use real clients for: Supabase, DAL, internal services

**Anti-Flakiness Requirements (CRITICAL):**
- Mock safety (from SESSION_CONSTANTS.mock_safety):
  - Config enforces: `restoreMocks: true`, `mockReset: true`
  - Use `vi.spyOn()` not `vi.mock()` unless silencing entire module
  - Never use `vi.clearAllMocks()` with module-level mocks
- Async patterns (from SESSION_CONSTANTS.async_patterns):
  - Use `findBy*` not `waitFor` + `getBy`
  - Use `await expect(locator).toBeVisible()` not `expect(await locator.isVisible()).toBe(true)`
  - Never use `waitForTimeout()` or `page.waitForTimeout()`
- Source: `~/.claude/rules/testing.md`

**Type safety (CRITICAL - WILL FAIL CI IF VIOLATED):**
- any type: BANNED
- Escape hatches BANNED: @ts-nocheck, @ts-ignore, @ts-expect-error
- Use unknown with validation if type truly unknown
- ESLint will reject any violations

**Common imports:**
```typescript
[imports_commonly_needed]
````

**ESLint & TypeScript Requirements (CRITICAL):**

- NEVER use `any` type - use specific types or `unknown` with runtime validation
- NEVER use TypeScript escape hatches: `@ts-nocheck`, `@ts-ignore`, `@ts-expect-error`
- Import only what you use - ESLint will fail on unused imports
- Properly type all variables, parameters, and return values
- Remove unused variables or prefix with underscore if intentionally unused: `_unused`
- Follow TypeScript strict mode - no implicit any, proper null checks

**Banned patterns (will fail CI):**

```typescript
// ❌ NEVER - These will be rejected
// @ts-nocheck
// @ts-ignore
// @ts-expect-error
const data: any = await fetchData();
const result = someFunc() as any;
import { unused } from 'lib';

// Mock internal services (use real clients)
vi.mock('@/lib/supabase/server');
vi.mock('@/lib/dal');

// ✅ CORRECT - Type-safe, proper boundaries
const data: UserData = await fetchData();
const result: string = someFunc();
// Only import what's used

// Use real Supabase client
const supabase = createClient(URL, SERVICE_ROLE_KEY);

// Only mock external services
vi.mock('ai', () => ({ ... }));
```

**Instructions:**

1. Read source file
2. Read existing test file (if any) for patterns
3. Read ONLY the relevant pattern sections from [skill-path]/references/test-patterns.md
   - For "server-actions-pattern" → Extract logic to logic.ts, test logic not wrapper
   - For "test-data-isolation" → Use createIsolatedTestHousehold() helper
   - For "self-cleaning-tests" → Track IDs, clean in afterAll
4. Write ALL test cases listed above following relevant patterns
5. Run tests for THIS file only: [pkg_manager] test -- [test_file_path]
6. If tests FAIL: Fix and retry. If still failing after 2 attempts, report failure.
7. Report completion

**Package manager:** [pkg_manager] (detected from lock file)

**Test requirement:** Tests MUST pass before reporting success.

When done, report:

- Tests written: [count] test cases
- Status: PASSING | FAILED (reason: ...)

````

**Spawn ONE writer per FILE** (parallel execution within folder).

**Key:** Each writer owns its file completely. No write conflicts.

### 2.5 Collect Writer Results & Update Tracker

**Orchestrator (you):**
1. Wait for all writers to complete
2. For each writer result:
   - **PASSING:** Mark file complete `- [x] lib/auth/logic.ts ✅`
   - **FAILED:** Mark file skipped `- [~] lib/auth/logic.ts ⚠️ Tests failed to pass, skipped`
3. Only commit PASSING tests (never commit failing tests)
4. Log skipped files for final summary

**Failure handling:** Writers that fail after retry attempts are skipped. Continue with remaining files.

**Why per-file writers?**
- No file write conflicts (each writer owns its file)
- Safe parallel test execution (different files)
- **100 agents at a time is absolutely fine** - each runs tests for its own file only
- Typical folder has 2-10 files = manageable parallelism

### 2.6 Loop: Process Next Folder

**If more Phase 1 folders remain:** Return to step 2.2, process next folder.

**If all Phase 1 folders processed:** Continue to step 2.8 (test → coverage → commit).

### 2.8 Run Test Suite & Check Coverage

**After all Phase 1 folders processed, validate and check coverage.**

#### Step 1: Run Full Test Suite

```bash
$PKG_MANAGER test
````

**If tests pass:** Continue to Step 1.5 (Lint & Fix).

**If tests fail:** Handle like Stage 0.4:

1. Parse test output to identify failing test files
2. Present options:

   ```
   ⚠️  Some newly written tests are failing:

   Failing tests:
   - lib/utils/validation.test.ts (1 test failed)

   **Options:**
   1. Skip these tests and generate coverage for remaining code
   2. Exit and fix tests first (use /test-fixer)
   ```

3. **If user chooses to skip:**
   - Add to `SKIP_TESTS` variable: `SKIP_TESTS="$SKIP_TESTS|validation.test.ts"`
   - Continue to Step 1.5
4. **If user chooses to exit:** Stop skill, user fixes tests

#### Step 1.5: Lint & Fix (Defense in Depth)

**After tests pass, before coverage generation, ensure ESLint compliance.**

**Note:** The PostToolUse ESLint hook should have caught most issues already. This phase provides defense in depth for edge cases and batch efficiency.

##### Sub-step 1: Auto-fix with ESLint

```bash
# Run ESLint auto-fix on all test files
cd "$project_root"
npx eslint --fix "**/*.test.ts" "**/*.test.tsx" --format json > /tmp/eslint-results.json || true
```

This auto-fixes ~80% of common issues:

- Unused imports
- Missing semicolons
- Formatting inconsistencies
- Simple type inference

##### Sub-step 2: Check for Remaining Errors

```bash
# Parse ESLint output for unfixable errors
python3 <skill-path>/scripts/parse_eslint_errors.py /tmp/eslint-results.json > /tmp/eslint-errors-by-file.json
exit_code=$?
```

**If exit_code = 0 (no errors):**

```
✅ All ESLint violations auto-fixed
Proceeding to coverage generation...
```

Continue to Step 2 (Generate Coverage).

**If exit_code = 1 (errors remain):**

Show summary:

```bash
error_file_count=$(jq 'keys | length' /tmp/eslint-errors-by-file.json)
echo "⚠️  $error_file_count file(s) have unfixable ESLint errors"
```

Continue to Sub-step 3 (Parallel Fix Agents).

##### Sub-step 3: Parallel Lint Fix Agents

**For each file with remaining errors**, spawn a **general-purpose agent** (Sonnet):

```
Task tool with:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Fix ESLint in [filename]"
- prompt: (see below)
```

**Lint-fix agent prompt:**

```
Fix ALL ESLint violations in this test file.

**File:** [file_path]

**ESLint errors:**
[errors from eslint-errors-by-file.json for this file]

**Instructions:**
1. Read the test file: [file_path]
2. Read project ESLint config to understand rules
3. For each ESLint error:
   - `@typescript-eslint/no-explicit-any`: Replace `any` with proper type or `unknown` + validation
   - `@typescript-eslint/no-unsafe-assignment`: Add type annotations
   - `@typescript-eslint/no-unsafe-call`: Fix type safety
   - Unused variables: Remove or prefix with underscore if intentionally unused
   - Missing types: Add proper TypeScript types
4. DO NOT change test logic, assertions, or test behavior
5. Run ESLint on just this file to verify: `npx eslint [file_path]`
6. If errors remain after fixing, iterate until clean
7. Report final status

**Critical Rules:**
- Only fix linting/type issues
- Preserve all test functionality
- Do not modify test data, assertions, or expectations
- Do not remove tests or change test coverage

When done, report:
- Errors fixed: [count]
- Status: CLEAN | STILL_HAS_ERRORS (list remaining)
```

**Spawn 1 agent per file** with errors (parallel execution).

##### Sub-step 4: Verify All Clean

After all fix agents complete:

```bash
# Re-run ESLint on all test files
npx eslint "**/*.test.ts" "**/*.test.tsx" --format json > /tmp/eslint-final.json || true
python3 <skill-path>/scripts/parse_eslint_errors.py /tmp/eslint-final.json
final_exit=$?
```

**If final_exit = 0:**

```
✅ All ESLint violations resolved
Files fixed: [count]
Proceeding to coverage generation...
```

Continue to Step 2 (Generate Coverage).

**If final_exit = 1 (edge case - some errors couldn't be fixed):**

```
⚠️ Some ESLint errors could not be auto-fixed

Files with remaining issues:
[list files from eslint-final.json]

**Options:**
1. Skip these files from commit (continue with passing files)
2. Exit and fix manually

Recommendation: Option 1 to make progress, fix manually later
```

**If user chooses skip:** Track skipped files, continue to Step 2
**If user chooses exit:** Stop skill

#### Step 2: Generate Coverage

```bash
# Regenerate coverage with updated skip list (if any new failures)
bash <skill-path>/scripts/generate_coverage.sh lib/ "$SKIP_TESTS"
```

Coverage now reflects passing tests only.

#### Step 3: Check Coverage

```bash
bash <skill-path>/scripts/verify_target.sh 95 lib/
```

**Output:**

```
📊 Current coverage: 82.5%
🎯 Target: 95%
⚠️  Gap: 12.5%
```

#### Step 3.5: Pre-commit Validation

**Before committing, ensure all code quality checks pass:**

```bash
# 1. Run Prettier format on all test files
npx prettier --write "**/*.test.ts" "**/*.test.tsx"

# 2. Run TypeScript check
npx tsc --noEmit

# 3. Final ESLint check (should be clean from Step 1.5)
npx eslint "**/*.test.ts" "**/*.test.tsx"

# 4. Run full test suite for Phase 1 (unit tests only)
$PKG_MANAGER test -- "**/*.test.ts" --exclude "**/integration/**"
```

**Error Handling Guidelines:**

**If Prettier formatting succeeds:**

- No action needed, changes auto-applied ✅

**If TypeScript check fails:**

```
❌ TypeScript errors detected:

[Show tsc output]

**Root cause:** PostToolUse hook should have caught these. Likely edge case.

**Options:**
1. Spawn fix agents to resolve TypeScript errors (1 per file)
2. Exit and fix manually

Recommendation: Option 1 (automated fix)
```

**If ESLint check fails:**

```
❌ ESLint errors detected:

[Show eslint output]

**Root cause:** Step 1.5 should have fixed these. Re-running fix phase.

**Action:** Re-run Step 1.5 Sub-steps 3-4 (Parallel fix agents + verify)
```

**If test suite fails:**

```
❌ Tests failing in pre-commit validation:

[Show test output]

**Options:**
1. Skip failing tests from commit (add to SKIP_TESTS)
2. Exit and fix tests first (use /test-fixer)

Recommendation: Option 1 to make progress
```

**If all checks pass:**

```
✅ Pre-commit validation passed
- Prettier: Formatted
- TypeScript: No errors
- ESLint: Clean
- Tests: All passing (Phase 1 unit tests)
Proceeding to commit...
```

#### Step 4: Decision & Commit

**If coverage >= 95%:**

```
🎉 Target reached with unit tests only! Phase 2 skipped.
Coverage: 45.3% → 96.2%
Phase 1 wrote 1,247 tests across 18 files.
Integration tests not needed.
```

**Commit all Phase 1 work:**

```bash
git add **/*.test.ts

git commit -m "test(lib): add unit test coverage (Phase 1 complete)

Coverage: 45.3% → 96.2% ✅ (Target: 95%)
Tests: 1,247 tests across 18 files
Phase: Unit tests only

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Go to Stage 3 (Completion).**

**If coverage < 95%:**

```
📊 Phase 1 complete: 45.3% → 82.5%
Phase 1 wrote 1,247 tests across 18 files.
Gap to target: 12.5%
Proceeding to Phase 2 (Integration Tests)...
```

**Commit all Phase 1 work:**

```bash
git add **/*.test.ts

git commit -m "test(lib): add unit test coverage (Phase 1 complete)

Coverage: 45.3% → 82.5%
Tests: 1,247 tests across 18 files
Phase: Unit tests (Phase 1)
Next: Integration tests (Phase 2)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Continue to Stage 2b (Phase 2).**

**Update TodoWrite:** If >= 95%, mark Stage 2b `completed`. If < 95%, mark Stage 2b `in_progress`.

---

## Stage 2b: PHASE 2 - Integration Tests

**Skip this stage if TEST_TYPE_PREFERENCE is "unit"**

**ONLY reached if Phase 1 coverage < 95% (when TEST_TYPE_PREFERENCE="all").**

**Goal:** Process ALL Phase 2 folders with STRICT verification, check coverage ONCE at end.

**This phase processes ALL integration test folders in sequence. Coverage is checked ONCE at the end, not after each folder.**

**Test type filtering:**

- If `TEST_TYPE_PREFERENCE="unit"`: **Skip this stage entirely → Go to Stage 3**
- If `TEST_TYPE_PREFERENCE="integration"`: Process Phase 2 normally (all files classified as integration)
- If `TEST_TYPE_PREFERENCE="e2e"`: Process Phase 2 but **filter to only E2E test files** (tests/e2e/ directory or page routes)
- If `TEST_TYPE_PREFERENCE="all"`: Process Phase 2 normally (auto-classification) only if Phase 1 < 95%

### 2b.1 Find All Phase 2 Folders

```bash
bash <skill-path>/scripts/verify_target.sh 95 lib/
```

**Decision:**

- **Coverage >= 95%?** → Skip Phase 2 entirely, go to Stage 3 ✅
  ```
  🎉 Target reached with unit tests only! Phase 2 skipped.
  Coverage: 45.3% → 82.1%
  Integration tests not needed.
  ```
- **Coverage < 95%?** → Continue to 2b.2 (Process Phase 2 folders)
  ```
  📊 Phase 1 complete: 45.3% → 72.8%
  Gap to target: 7.2%
  Proceeding to Phase 2 (Integration Tests)...
  ```

**Update TodoWrite:** If >= 95%, mark Stage 2b `completed`. If < 95%, mark Stage 2b `in_progress`.

### 2b.2 Find All Phase 2 Folders

Read tracker and extract ALL folders under "## PHASE 2: INTEGRATION TESTS" section:

```bash
# Extract all Phase 2 folders with unchecked items
sed -n '/^## PHASE 2/,$ p' .claude/docs/test-coverage-tracker.md | grep "^### Folder"
```

**If NO folders in Phase 2:** Go to Stage 3 (Completion)

**If folders found:** Process ALL of them in sequence (steps 2b.3-2b.7)

### 2b.3 Process Each Folder (Loop)

**For EACH folder from 2b.2**, follow steps 2b.4-2b.7 below. Do NOT check coverage between folders.

### 2b.4 Plan Tests for Current Folder (Sonnet Planners - Integration Test Focus)

For files in THIS folder only, spawn **Sonnet planner agents in parallel** with integration test guidance:

**Planner prompt template:**

````
Plan test cases for this file to improve coverage.

**File classification:** INTEGRATION TEST (Phase 2)

**Test type guidance:**
- STRICT verification required
- Must use createIsolatedTestHousehold() helper
- Must implement afterAll cleanup
- Must pass 3 consecutive runs (flakiness check)
- Real Supabase client with SERVICE_ROLE_KEY

**Session constants (project-specific patterns):**
[Include relevant session constants from Stage 0.6]
- Test command: [test_command from SESSION_CONSTANTS]
- Test pattern: [test_file_pattern] ([test_file_suffix] files)
- Test helpers: [list key helpers with import paths]
- Standards: [list applicable rules/docs]
- Common imports:
  ```typescript
  [imports_commonly_needed from SESSION_CONSTANTS]
````

[Rest of planner structure same as Phase 1: source file, uncovered functions, output format, pattern identification guide]

```

### 2b.5 Write Tests for Current Folder (Sonnet Test Writers - Integration Test STRICT Verification)

For each FILE in this folder, spawn **Sonnet test-writer agents in parallel** with STRICT verification:

**Writer prompt template:**
```

Write ALL test cases for this file.

**Test type:** INTEGRATION TEST

**Source file:** [file_path]
**Test file:** [test_file_path]
**File type:** [file_type from planner]

**Test cases to write:**
[List all test cases from tracker for this file]

**Session constants (project-specific patterns discovered from codebase):**
[Include from Stage 0.6 SESSION_CONSTANTS]

**Test execution:**

- Command: [test_command]
- Pattern: [test_file_pattern] ([test_file_suffix] files)

**Test helpers available:**
[For each helper:]

- [name]: [path]
  Usage: [usage_example]

**Mocking philosophy (CRITICAL):**

- NEVER mock: [internal_services_never_mock]
- OK to mock: [external_services_mocked]
- Use REAL Supabase client for integration tests

**Anti-Flakiness Requirements (CRITICAL):**

- Mock safety (from SESSION_CONSTANTS.mock_safety):
  - Config enforces: `restoreMocks: true`, `mockReset: true`
  - Use `vi.spyOn()` not `vi.mock()` unless silencing entire module
  - Never use `vi.clearAllMocks()` with module-level mocks
- Async patterns (from SESSION_CONSTANTS.async_patterns):
  - Use `findBy*` not `waitFor` + `getBy`
  - Use `await expect(locator).toBeVisible()` not `expect(await locator.isVisible()).toBe(true)`
  - Never use `waitForTimeout()` or `page.waitForTimeout()`
- Source: `~/.claude/rules/testing.md`

**Type safety (CRITICAL - WILL FAIL CI IF VIOLATED):**

- any type: BANNED
- Escape hatches BANNED: @ts-nocheck, @ts-ignore, @ts-expect-error
- Use unknown with validation if type truly unknown

**Integration test pattern:**
[SESSION_CONSTANTS.integration_test_pattern.example_structure]

**Common imports:**

```typescript
[imports_commonly_needed];
```

**ESLint & TypeScript Requirements (CRITICAL):**

- NEVER use `any` type - use specific types or `unknown` with runtime validation
- NEVER use TypeScript escape hatches: `@ts-nocheck`, `@ts-ignore`, `@ts-expect-error`
- Import only what you use - ESLint will fail on unused imports
- Properly type all variables, parameters, and return values
- Remove unused variables or prefix with underscore if intentionally unused
- Follow TypeScript strict mode - no implicit any, proper null checks

**INTEGRATION TEST VERIFICATION (STRICT - REQUIRED):** 7. Write ALL test cases with REAL Supabase client 8. Use createIsolatedTestHousehold() helper 9. Track all created IDs in arrays 10. Implement afterAll cleanup (delete children before parents) 11. Run tests 3 CONSECUTIVE TIMES:
`bash
    for i in {1..3}; do [pkg_manager] test -- [test_file_path] || exit 1; done
    ` 12. ALL 3 runs must pass (no flakiness allowed) 13. If any run fails: Investigate timing/race conditions, fix, retry

**Required patterns:**

```typescript
import { createIsolatedTestHousehold } from "@/tests/helpers/isolated-test-household";

describe("Recipe actions", () => {
  let supabase: ReturnType<typeof createClient>;
  let household: IsolatedTestHousehold;
  let createdIds: string[] = [];

  beforeAll(async () => {
    supabase = createClient(URL, SERVICE_ROLE_KEY);
    household = await createIsolatedTestHousehold(supabase);
  });

  afterAll(async () => {
    await supabase.from("table").delete().in("id", createdIds);
    await cleanupIsolatedTestHousehold(supabase, household.householdId);
  });

  it("test case", async () => {
    const result = await functionUnderTest(supabase, household.householdId);
    createdIds.push(result.id);
    expect(result.success).toBe(true);
  });
});
```

When done, report:

- Tests written: [count]
- Multi-run result: [3/3 PASSED] or [2/3 PASSED - FLAKY]
- Status: PASSING | FLAKY | FAILED

````

### 2b.6 Collect Results for Current Folder

**Orchestrator tracking:**
- **PASSING:** All 3 runs passed → Mark `- [x] file.ts ✅ (3/3 runs)`
- **FLAKY:** 2/3 runs passed → Mark `- [~] file.ts ⚠️ Flaky (2/3 runs)` - will skip from coverage
- **FAILED:** <2 runs passed → Mark `- [~] file.ts ❌ Tests failed` - will skip from coverage

Track all FLAKY/FAILED test files for potential skip list.

### 2b.7 Loop: Process Next Folder

**Return to step 2b.3** to process the next Phase 2 folder.

**Do NOT check coverage or commit yet.** Continue until ALL Phase 2 folders are processed.

### 2b.8 Run Test Suite & Check Coverage

**After ALL Phase 2 folders are processed** (no more folders to process from 2b.3):

#### Step 1: Run Full Test Suite

```bash
$PKG_MANAGER test
````

**If tests pass:** Continue to Step 1.5 (Lint & Fix).

**If tests fail:**

1. Parse output to identify failing test files
2. Present skip option to user:
   - "Some tests failed. Skip these and generate coverage for remaining code?"
   - "Exit and fix tests first (use /test-fixer)"
3. If user chooses skip:
   - Update `SKIP_TESTS` variable: `SKIP_TESTS="$SKIP_TESTS|new-failing.test.ts"`
   - Continue to Step 1.5
4. If user chooses exit: Stop skill

#### Step 1.5: Lint & Fix (Defense in Depth)

**After tests pass, before coverage generation, ensure ESLint compliance.**

**Note:** The PostToolUse ESLint hook should have caught most issues already. This phase provides defense in depth for edge cases and batch efficiency.

##### Sub-step 1: Auto-fix with ESLint

```bash
# Run ESLint auto-fix on all test files
cd "$project_root"
npx eslint --fix "**/*.test.ts" "**/*.test.tsx" --format json > /tmp/eslint-results.json || true
```

##### Sub-step 2: Check for Remaining Errors

```bash
python3 <skill-path>/scripts/parse_eslint_errors.py /tmp/eslint-results.json > /tmp/eslint-errors-by-file.json
exit_code=$?
```

**If exit_code = 0:** Continue to Step 2 (Generate Coverage).

**If exit_code = 1 (errors remain):** Continue to Sub-step 3.

##### Sub-step 3: Parallel Lint Fix Agents

For each file with errors, spawn **general-purpose agent** (Sonnet) with the same prompt as Phase 1.

##### Sub-step 4: Verify All Clean

```bash
npx eslint "**/*.test.ts" "**/*.test.tsx" --format json > /tmp/eslint-final.json || true
python3 <skill-path>/scripts/parse_eslint_errors.py /tmp/eslint-final.json
final_exit=$?
```

**If final_exit = 0:** Continue to Step 2.

**If final_exit = 1:** Present skip/exit options to user.

#### Step 2: Generate Coverage

```bash
bash <skill-path>/scripts/generate_coverage.sh lib/ "$SKIP_TESTS"
```

This will:

- Generate coverage with any skipped tests excluded
- Output JSON to `./coverage/coverage-final.json`
- Output HTML to `./coverage/index.html`

#### Step 3: Check Coverage

```bash
bash <skill-path>/scripts/verify_target.sh 95 lib/
```

**Decision:**

- **Coverage >= 95%?** → Proceed to Step 3.5 (Pre-commit Validation) ✅
- **Coverage < 95%?** → Proceed to Step 3.5 (Pre-commit Validation)

Coverage will be rechecked at Stage 3 for final status.

#### Step 3.5: Pre-commit Validation

**Before committing, ensure all code quality checks pass:**

```bash
# 1. Run Prettier format on all test files
npx prettier --write "**/*.test.ts" "**/*.test.tsx"

# 2. Run TypeScript check
npx tsc --noEmit

# 3. Final ESLint check (should be clean from Step 1.5)
npx eslint "**/*.test.ts" "**/*.test.tsx"

# 4. Run full test suite for Phase 2 (integration tests only)
# Note: This re-runs all Phase 2 tests to ensure no regressions
$PKG_MANAGER test -- "**/integration/**/*.test.ts"
```

**Error Handling Guidelines:**

Use the same error handling approach as Phase 1 Step 3.5:

- **Prettier:** Auto-applied ✅
- **TypeScript errors:** Spawn fix agents or exit
- **ESLint errors:** Re-run Step 1.5 fix phase
- **Test failures:** Skip from commit or exit

**If all checks pass:**

```
✅ Pre-commit validation passed
- Prettier: Formatted
- TypeScript: No errors
- ESLint: Clean
- Tests: All passing (Phase 2 integration tests)
Proceeding to commit...
```

#### Step 4: Commit Phase 2

```bash
git add **/*.test.ts

git commit -m "test(lib): add integration test coverage (Phase 2 complete)

Coverage: 72.8% → 83.1% (or current %)
Tests: [N] integration tests
Verification: 3/3 runs per file (strict)

Phase 2 complete.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Update TodoWrite:** Mark Phase 2 (Stage 2b) as `completed`, Stage 3 as `in_progress`.

---

## Stage 3: Completion & Summary

**Reached when coverage >= 95% OR all folders processed.**

### 3.1 Final Coverage Report

```bash
bash <skill-path>/scripts/verify_target.sh 95 lib/
```

### 3.2 Generate Summary

Read tracker and count:

- Phase 1 vs Phase 2 breakdown
- Folders processed in each phase
- Test cases written
- Files covered
- Coverage increase

**Example: Phase 1 reached target (Phase 2 skipped):**

```
🎉 Test Coverage Retrofit Complete!

**Coverage:** 45.3% → 82.1% ✅ (Target: 95%)
**Scope:** lib/

---

**PHASE 1: UNIT TESTS**
✅ Folders processed: 2 of 2
✅ Coverage gain: 45.3% → 82.1% (+36.8%)
⚡ Verification: 1-2 runs per file (fast)
📊 Files covered: 12

**PHASE 2: INTEGRATION TESTS**
⏭️  SKIPPED - Target reached with Phase 1 alone

---

**Quality Metrics:**
- Unit tests: 12 files, 100% passing
- Integration tests: Not needed
- Total test cases: 38

⚠️  **Pre-existing test failures (skipped for coverage):**
- app/lib/utils.test.ts (excluded from coverage)
- Fix these separately using /test-fixer

**Next steps:**
- Review HTML report: ./coverage/index.html
- Run full test suite: [pkg_manager] test
- Fix skipped tests: /test-fixer
- Create PR or commit remaining changes
```

**Example: Both phases needed:**

```
🎉 Test Coverage Retrofit Complete!

**Coverage:** 45.3% → 83.1% ✅ (Target: 95%)
**Scope:** lib/

---

**PHASE 1: UNIT TESTS**
✅ Folders processed: 2 of 2
✅ Coverage gain: 45.3% → 72.8% (+27.5%)
⚡ Verification: 1-2 runs per file (fast)
📊 Files covered: 10

**PHASE 2: INTEGRATION TESTS**
✅ Folders processed: 1 of 2 (stopped early - target reached!)
✅ Coverage gain: 72.8% → 83.1% (+10.3%)
🔒 Verification: 3/3 runs per file (strict)
📊 Files covered: 3

---

**Quality Metrics:**
- Unit tests: 10 files, 100% passing
- Integration tests: 3 files, 100% passing (all 3/3 runs)
- Skipped files: 4 (target reached early)
- Total test cases: 45

⚠️  **Flagged issues:**
- lib/api/search-logic.ts: Tests flaky (2/3 runs) - skipped

⚠️  **Pre-existing test failures (skipped for coverage):**
- app/lib/utils.test.ts (excluded from coverage)
- Fix these separately using /test-fixer

**Next steps:**
- Review HTML report: ./coverage/index.html
- Run full test suite: [pkg_manager] test
- Fix skipped tests: /test-fixer
- Review flaky tests before merging
- Create PR or commit remaining changes
```

### 3.3 Commit Remaining Changes (If Any)

**Check for uncommitted test files:**

```bash
git status --porcelain | grep '\.test\.ts$\|\.spec\.ts$'
```

**If uncommitted test files exist:**

**Git dirty check:**

```bash
# Check for uncommitted changes beyond test files
git status --porcelain | grep -v '\.test\.ts$' | grep -v '\.spec\.ts$'
```

**If uncommitted non-test changes detected:**

```
⚠️  Warning: Uncommitted changes detected beyond test files.
   Only test files will be committed.
```

**Proceed with test-only commit:**

```bash
git add **/*.test.ts

git commit -m "test(lib): retrofit unit test coverage to 82.1%

Systematic coverage improvement using parallel test writers.

Folders:
- lib/auth/: 12% → 78%
- lib/api/: 35% → 86%

Tests: 23 test cases across 7 files
Target: 95% (REACHED)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Update TodoWrite:** Mark Stage 3 `completed`. All done!

---

## Quality Guidelines for Test Writers

### Test Patterns

Agents follow [test-patterns.md](references/test-patterns.md):

- **Integration over unit** - Test behavior, not implementation
- **Dynamic test data** - No hardcoded IDs (`crypto.randomUUID()`)
- **Self-cleaning** - Track IDs, clean in `afterAll`
- **Mock boundaries** - External APIs only, not internal wrappers
- **No `any` types** - Use `unknown` with validation
- **Stable tests** - No arbitrary timeouts, proper waits

### Server Actions (Next.js)

Extract logic to separate `logic.ts` files. Test logic, not action wrapper.

See [test-patterns.md - Server Actions](references/test-patterns.md#server-actions-pattern).

### Common Pitfalls to Avoid

1. **Flaky tests** - Arbitrary timeouts, race conditions
2. **Hardcoded test data** - Brittle, causes collisions
3. **Over-mocking** - Mocking internal code instead of external APIs
4. **Implementation testing** - Testing private methods instead of behavior
5. **No cleanup** - Test pollution, state leakage

### Code Quality Checks (Defense in Depth)

**Four-layer approach to ensure clean, production-ready code:**

1. **Prevention (PostToolUse Hooks)**
   - TypeScript & ESLint PostToolUse hooks run after every Write/Edit
   - Catches errors immediately in subagent context
   - Subagents see errors and fix them before completing
   - **Setup:** Add hooks to `~/.claude/settings.json`

2. **Auto-fix (Batch ESLint --fix)**
   - After all tests pass, run `npx eslint --fix` on all test files
   - Auto-fixes ~80% of common issues (unused imports, formatting, etc.)
   - Fast batch operation on all files at once
   - **Location:** Step 1.5 in both Phase 1 and Phase 2

3. **Manual Fix (Parallel Sonnet Agents)**
   - For complex errors that `--fix` can't handle
   - Spawn 1 Sonnet agent per file with remaining errors
   - Each agent fixes ESLint violations without changing test logic
   - Graceful degradation: Offers skip option if fixes fail

4. **Pre-commit Validation**
   - Before committing, run Prettier + TypeScript + ESLint
   - Ensures no issues slipped through previous layers
   - Auto-applies Prettier formatting
   - **Location:** Step 3.5 in both Phase 1 and Phase 2

**Why all four layers?**

- Hooks prevent most issues (subagents fix before completing)
- Batch auto-fix handles edge cases and is more efficient
- Manual fix agents handle complex type issues
- Pre-commit validation is final safety net
- Result: Only clean, formatted code gets committed

**Scripts:**

- `parse_eslint_errors.py` - Parses ESLint JSON output, groups errors by file
- `eslint-check-posttooluse.sh` - PostToolUse hook for immediate feedback

---

## Scripts Reference

| Script                   | Purpose                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `generate_coverage.sh`   | Run Vitest with coverage, output JSON + HTML                       |
| `parse_coverage.py`      | Parse JSON, prioritize files, output structured data               |
| `create_tracker.py`      | Generate tracking document from parsed data                        |
| `verify_target.sh`       | Check if coverage target reached                                   |
| `parse_eslint_errors.py` | Parse ESLint JSON output, group errors by file for parallel fixing |

---

## References

- [test-patterns.md](references/test-patterns.md) - Best practices for writing good tests
- [test-writer-instructions.md](references/test-writer-instructions.md) - Instructions for Haiku agents
- [vitest-coverage.md](references/vitest-coverage.md) - How Vitest coverage works

---

## Key Differences from `/unit-test-retrofit`

| Feature        | `/unit-test-retrofit`         | This Skill                         |
| -------------- | ----------------------------- | ---------------------------------- |
| **Driver**     | Gap analysis (untested files) | Coverage report (uncovered lines)  |
| **Target**     | 100% of untested files        | 95% overall coverage               |
| **Execution**  | Sequential per test case      | Parallel per file                  |
| **Validation** | Mutation testing              | Tests must pass + quality patterns |
| **Scope**      | Entire codebase               | Configurable (directory-based)     |
| **Priority**   | All files equal               | Critical paths first               |

**Use this skill when:** Retrofitting coverage systematically with quality focus.

**Use `/unit-test-retrofit` when:** Need mutation testing validation (more rigorous but slower).

---

## Tips

1. **Start small** - Pick one directory (e.g., `lib/`) not entire codebase
2. **Trust the discovery phase** - Sonnet learns your architecture once, guides all subsequent agents
3. **Architecture compatibility is key** - Discovery prevents generating incompatible tests (mocks vs real clients, type safety violations)
4. **95% is the new optimal** - AI-era sweet spot for production (error paths + edge cases without unreachable code headaches)
5. **Review HTML report** - Visual feedback helps identify remaining gaps
6. **Commit often** - Don't lose work if agents fail midway

**Discovery phase investment:** Sonnet costs ~$0.10 for discovery but prevents regenerating thousands of incompatible tests. This upfront investment pays for itself immediately.

**Why 95% not 80%?** In the AI era, test generation is cheap. The last 15% (error handling, edge cases) contains high-value code that's often untested and breaks in production. Traditional 80% rule assumed expensive manual test writing—that constraint no longer applies.

**Architecture awareness:** Discovery phase identifies:

- Mocking philosophy (integration vs unit, real clients vs mocks)
- Type safety requirements (banned escape hatches, ESLint rules)
- Integration test patterns (cleanup, helpers, data isolation)
- Test helpers and their usage patterns

**Remember:** Coverage is a tool, not a goal. Good tests > high coverage %. But with discovery-driven generation, you get BOTH quality AND coverage.
