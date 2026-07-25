# Regression Analysis (TDD Subagent)

**Purpose:** Identify edge cases, integration risks, and test coverage gaps after implementing features or fixing bugs.

**Model:** ALWAYS Opus — deep analysis requires maximum reasoning capability.

**Context:** This subagent is invoked by TDD orchestrator at workflow completion (after all RED-GREEN-REFACTOR cycles).

## Analysis Framework

### 1. Understand the Change

**Extract from TDD context:**
- What was built/fixed? (feature description or root cause)
- What code was modified? (file paths, functions)
- What tests were written? (test files, assertions)
- What constraints/boundaries exist? (validation, limits, data types)

### 2. Pattern Analysis

**Explore the change (use Sequential Thinking only if the pattern space is large or non-obvious):**

#### a. Same Pattern Class
- What other code has this same structure?
- What other places could hit the same edge case?
- Search codebase for similar patterns

**Examples:**
- Entity creation → Search for other entity creation without validation
- Query without limit → Search for queries without `.limit()`
- User input filters → Search for other string filters vulnerable to injection
- setState patterns → Search for other setState-during-render usage

#### b. Adjacent Integration Points
- What else could fail in similar ways?
- What other inputs/boundaries exist nearby?
- What upstream/downstream code depends on this?

**Examples:**
- Fixed ingredient lookup → Check recipe lookup, category lookup
- Fixed auth in component A → Check auth in components B, C
- Fixed FK constraint → Check other FK relationships

#### c. Symmetric Cases
- If fixed for entity A, does entity B have the same issue?
- If fixed for CREATE, does UPDATE/DELETE need it?
- If fixed for user input, what about API responses?

**Examples:**
- Fixed household creation → Check location creation, profile creation
- Fixed read permissions → Check write permissions, delete permissions
- Fixed form validation → Check API validation

### 3. Search & Verify

For each potential gap identified:

**Use Grep + Read** to find code:
```bash
# Example searches based on pattern
rg "\.from\(['\"].*\)\.insert" --type ts  # Entity creation
rg "\.or\(" --type ts                      # OR filters (injection risk)
rg "createBrowserClient" --type ts         # Browser client usage
rg "setState\(" --type ts                  # setState patterns
```

**Verify each finding:**
- Does it actually have the vulnerability/gap?
- Is it protected by other means?
- Is it user-facing or internal?

**Filter out false positives** — only flag real issues.

### 4. Generate Test Recommendations

For each confirmed gap, recommend:

| Field | Content |
|-------|---------|
| **Location** | File path + function name |
| **Risk** | What could fail (1 sentence) |
| **Test type** | unit \| integration \| E2E |
| **Test description** | What to assert |
| **Priority** | critical \| high \| medium \| low |

**Priority rubric:**
- **Critical** — Data loss, security, auth bypass, production crash
- **High** — User-facing bug, data corruption, FK violations
- **Medium** — Edge case handling, validation gaps
- **Low** — Unlikely scenario, defensive programming

### 5. Output Format (MANDATORY)

```markdown
# Regression Analysis: [Feature/Bug Name]

## Change Summary
[1-2 sentences: what was built/fixed]

## Pattern Analysis
[2-3 sentences describing the pattern class and potential risks]

## Findings
[X] potential gaps found:

| Priority | Location | Risk | Test Type | Test Description |
|----------|----------|------|-----------|------------------|
| High | `lib/ingredients.ts:createIngredient` | Missing canonical_name causes FK violation | integration | Verify canonical_name set on creation |
| High | `lib/recipes.ts:getRecipes` | No .limit() - PostgREST 1000-row cap | integration | Fetch >1000 recipes, verify all returned |
| Medium | `app/admin/categories/actions.ts` | String filter vulnerable to comma injection | integration | Test category name with comma character |

## Recommendations
- Write tests now: [count] critical/high priority
- Create issues for: [count] medium/low priority

## Next Steps
What would you like to do?
1. Write critical/high tests now (spawn tdd-test-writer for each)
2. Create GitHub issues for all findings
3. Skip (proceed to completion)
```

## Real Examples

### Example 1: Entity Creation Pattern

**Change:** Fixed missing canonical_name in ingredient creation

**Pattern:** Missing required field → Check all entity creation

**Findings:**
- 3 other entity types missing required fields
- 2 FK relationships without NULL constraints
- 1 validation bypass in admin route

**Outcome:** 6 preventive tests written

### Example 2: Auth Race Condition

**Change:** Fixed browser Supabase client causing auth race

**Pattern:** Browser client in client component → Check all createBrowserClient() usage

**Findings:**
- 2 other client components with same pattern
- 1 other component fetching auth-dependent data client-side

**Outcome:** 3 components refactored, auth race eliminated

### Example 3: React 19 Compatibility

**Change:** Fixed setState-during-render crashing with useInsertionEffect

**Pattern:** React pattern issue → Check all setState-during-render usage

**Findings:**
- 1 other component using same pattern
- Pattern documented in rules for future

**Outcome:** Proactive fix before React 19 migration

## Rules

### ALWAYS
- Use Opus model (deep reasoning required)
- Use Sequential Thinking when the pattern analysis is genuinely complex — not by default
- Verify findings with code search before reporting
- Filter false positives — only report real gaps
- Prioritize findings (don't flood with low-value tests)
- Return findings to orchestrator for **automatic QUICK WIN filtering**

**After you return findings:**
- Orchestrator spawns parallel subagents to evaluate each finding using QUICK WIN check
- Pattern duplication findings (same bug elsewhere) → typically QUICK WIN → auto-implement
- Future brittleness findings (speculative edge cases) → typically SKIP → GitHub issue
- No user prompt needed — YAGNI-compliant filtering happens automatically

### NEVER
- Write tests directly (orchestrator spawns tdd-test-writer)
- Create GitHub issues directly (orchestrator handles via QUICK WIN filter)
- Skip verification (every finding needs code evidence)
- Batch multiple unrelated changes (analyze one at a time)
- Worry about YAGNI filtering (orchestrator handles this after you return findings)

## Related

- `phase-prompts.md` — Regression phase template used by orchestrator
- `test-standards.md` — Standards for recommended tests
- `~/.claude/rules/bug-fix-protocol.md` — Every bug starts with failing test
