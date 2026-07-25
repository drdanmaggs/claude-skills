# Planning Workflow (Stage 0)

Complete reference for TDD Stage 0 planning gate and automated plan generation.

## Overview

**Execution model:** Autonomous — skill runs end-to-end once invoked.

**User controls:**
- Ctrl+C to abort at any stage
- Plan file can be edited manually before resuming
- Slices can be reordered/modified in plan file

Stage 0 has two paths based on complexity:
1. **Auto-generate plan** (Plan subagent) - For features needing structure (complex or intermediate)
2. **Skip planning** (manual) - For simple/well-understood tasks

**NEVER use `EnterPlanMode`.** It causes context amnesia — the orchestrator forgets the TDD skill after exiting plan mode. All planning stays in the main conversation via Plan subagent.

## The Planning Heuristic

**Central question:**
> "Given this description, could a junior developer with limited intelligence and no taste implement this successfully without additional guidance?"

### Evaluation Criteria

Ask these questions about the user's description:

| Question | What It Checks |
|----------|----------------|
| Is the goal clear and specific? | Vague "improve performance" vs specific "add caching to API" |
| Are acceptance criteria defined? | "Working" is measurable |
| Is the scope well-bounded? | Clear what's in/out of scope |
| Are architectural decisions made or obvious? | Storage approach, API patterns, state management decided |
| Are edge cases and error handling identified? | User thought about failure modes |
| Would a junior dev know which files to modify? | Sufficient context about codebase location |

### Three Outcomes

**A) COMPLEX** - NO to multiple criteria

Junior dev would struggle. Needs collaborative planning to:
- Clarify architecture
- Explore implementation approaches
- Identify critical files and integration points
- Define acceptance criteria

**Example signals:**
- "Migrate auth to OAuth2" (many decisions needed)
- "Refactor the data layer" (unclear scope)
- "Add real-time features" (WebSockets vs SSE vs polling?)
- Multiple "I'm not sure" or "maybe" in description

**B) INTERMEDIATE** - Mostly YES, some uncertainty

Junior dev could do it but would benefit from structured guidance:
- Goal is clear
- Scope is mostly defined
- Some edge cases or patterns uncertain

**Example signals:**
- "Add category search with filtering" (clear goal, some details TBD)
- "Implement password reset flow" (known pattern, some specifics needed)
- "Add pagination to recipes list" (straightforward, but which approach?)

**C) SIMPLE** - YES to all criteria

Junior dev could implement this directly:
- Goal crystal clear
- Implementation obvious
- Edge cases identified or trivial
- Files to modify known

**Example signals:**
- "Add slugify helper to utils" (single function, clear purpose)
- "Fix null check in ingredient validation" (specific, localized)
- "Update error message for duplicate names" (trivial)

## Path A: REMOVED — Do Not Use EnterPlanMode

`EnterPlanMode` causes context amnesia — the orchestrator forgets the TDD skill after exiting. **All planning now goes through Path B (Plan subagent).**

For **COMPLEX** features that need more user input before planning:
1. Use `AskUserQuestion` to gather requirements (architecture, constraints, edge cases)
2. Then proceed to **Path B** with the enriched context

## Path B: Auto-Generate Plan (Plan Subagent)

**When:** User chose "Auto-generate plan" from heuristic gate.

### Spawning Plan Subagent

```
Task tool:
  subagent_type: "Plan"
  model: "sonnet"
  description: "Generate TDD implementation plan"
  prompt: |
    Read this tdd skill's bundled `references/test-standards.md` for testing patterns (the orchestrator passes its absolute path).

    Task: Create a TDD implementation plan in Kent Beck format.

    Feature/Bug: {user's description}

    Required format:
    # TDD Plan: [feature name]

    ## Context
    [1-2 sentences: what problem this solves]

    ## Architecture
    [2-3 sentences: chosen approach, critical files, integration points]

    ## Session Constants
    Test command: [infer from project, e.g., pnpm vitest run]
    Test file pattern: [infer from project structure]
    Test helpers: [identify from tests/helpers/ or similar]

    ## Slice 1: [foundation — core logic/data model]
    Type: unit | Status: pending
    Files: [exact paths to test and implementation files]

    - [ ] [specific test case — happy path]
    - [ ] [edge case — empty input]
    - [ ] [edge case — invalid input]

    ## Slice 2: [next layer — integration/API]
    Type: integration | Status: pending
    Files: [exact paths]

    - [ ] [test case]
    - [ ] [test case]

    [Additional slices as needed]

    Guidelines:
    - Each slice builds on previous (incremental)
    - 3-6 slices typical (fewer for simple, more for complex)
    - Identify actual file paths from codebase
    - Include edge cases and error handling
    - Consider RLS, validation, concurrency where relevant
```

### After Plan Subagent Returns

1. **Save plan**
   - Save to `docs/plans/YYYY-MM-DD-<feature-slug>.md`
   - Use today's date
   - Slugify feature name (lowercase, hyphens)

2. **Present plan to user** (for visibility)

   *Note: User can Ctrl+C to abort if plan needs adjustment.*

3. **Extract session constants**
   - Pull from plan (test command, patterns, helpers)

4. **Create slice tasks**
   Call `TaskCreate` once per slice (same format as Path A step 7).

5. **Skip to The Loop**
   - Proceed with first slice in plan

## Path C: Skip Planning (Manual Flow)

**When:** User chose "Skip planning" OR bug fix mode.

This is the original TDD workflow before planning integration.

### 0a. Explore & Discover Session Constants

Spawn Explore agent (`subagent_type="Explore"`, thoroughness `"very thorough"`).

**Find:**
- Relevant files and modules for this task
- Existing test patterns (helpers, fixtures, naming conventions)
- Dependencies and integration points
- Similar features/tests to use as templates

**Discover session constants:**
- Test command: `pnpm vitest run --reporter=verbose`
- Test file pattern: colocated `*.test.ts` or `tests/__tests__/`
- Test helpers: `tests/helpers/isolated-test-household.ts`
- Standards file: this skill's bundled `references/test-standards.md` (absolute path resolved in Stage 0)
- Bug context: PR #123 or main..fix/bug or diagnosis (empty for features)

### 0b. Clarify Intent

**Ask the user questions before planning.** Exploration findings inform what to ask.

Focus on:
- What does "working" look like? (acceptance criteria)
- What's the scope? (MVP vs full feature)
- Any constraints? (existing patterns to follow, DB schema decisions)
- Which test types matter? (unit only? integration? E2E?)

If a GitHub issue exists, read it (including comments) — but still confirm understanding.

**Do not proceed until you understand what the user wants.**

### 0c. Decompose into Slices

**Use Context7 MCP** first if feature involves framework behavior (Next.js, Supabase, React).

Decompose into ordered incremental slices — each slice = one RED-GREEN-REFACTOR cycle that builds on the previous. Reason inline; reach for Sequential Thinking only if the decomposition is genuinely tangled.

**Output format (for user approval):**

```
Feature: [name]

Slice 1: [foundation — e.g., core data model + validation]
  Type: unit | Builds on: nothing
  Covers: happy path, empty input, whitespace handling

Slice 2: [next layer — e.g., API endpoint]
  Type: integration | Builds on: Slice 1
  Covers: CRUD operations, validation errors, not-found, RLS enforcement

Slice 3: [edge cases + error handling]
  Type: unit + integration | Builds on: Slices 1-2
  Covers: concurrency, duplicate handling
```

**Present slices to user** (for visibility). Proceed directly to plan decomposition.

*Note: User can still Ctrl+C to abort before decomposition begins.*

### 0d. Write Plan

After user approves slices, **decompose each slice into individual tests** and write to `docs/plans/YYYY-MM-DD-<feature-slug>.md`. (Use Sequential Thinking only if a slice is genuinely hard to break down.)

Use today's date. Slugify the feature name (lowercase, hyphens).

```markdown
# TDD Plan: [feature name]

## Context
[1-2 sentences: what problem this solves]

## Architecture
[2-3 sentences: chosen approach]

## Session Constants
Test command: [from explore]
Test file pattern: [from explore]
Test helpers: [from explore]

## Slice 1: [description]
Type: unit | Status: pending
Files: [exact paths]

- [ ] returns valid result for normal input
- [ ] rejects empty name
- [ ] trims whitespace from input

## Slice 2: [description]
Type: integration | Status: pending
Files: [exact paths]

- [ ] creates record and returns ID
- [ ] returns 400 for invalid payload
- [ ] returns 404 when parent not found
- [ ] enforces RLS — user can only access own data
```

Call `TaskCreate` once per slice for user-facing progress.

## Comparison: Two Paths

| Aspect | Auto-Plan (Path B) | Manual (Path C) |
|--------|-------------------|-----------------|
| **User involvement** | Low (review only) | Medium (Q&A) |
| **Time** | Fast (~2-3 min) | Medium (~5-7 min) |
| **Best for** | Most features | Simple, familiar tasks |
| **Plan format** | Kent Beck (strict) | Kent Beck (strict) |
| **For complex features** | AskUserQuestion first, then auto-plan | N/A |

## Decision Matrix

| User Description | Heuristic Result | Recommended Path | Why |
|------------------|------------------|------------------|-----|
| "Add OAuth2 login" | COMPLEX | Auto-plan (Q&A first) | Gather requirements via AskUserQuestion, then Plan subagent |
| "Add search to categories API" | INTERMEDIATE | Auto-plan | Clear goal, some detail TBD (filters, pagination) |
| "Fix typo in validation message" | SIMPLE | Skip planning | Trivial, no planning needed |
| "Refactor data layer for performance" | COMPLEX | Auto-plan (Q&A first) | Clarify scope via AskUserQuestion, then Plan subagent |
| "Add password reset email flow" | INTERMEDIATE | Auto-plan | Known pattern, specific implementation choices |
| "Extract slugify to helper function" | SIMPLE | Skip planning | Single function, obvious |

## Tips for Orchestrator

**When applying heuristic:**
- Be honest in evaluation - don't force SIMPLE if there are unknowns
- Consider user's experience level (junior user = more planning helpful)
- Bug fixes typically SIMPLE unless root cause is complex

**When presenting choices:**
- Make recommendation clear ([RECOMMENDED] tag)
- Explain why (1-2 sentences)
- Respect user override (they know their context best)

**When plan generated (auto or manual):**
- Present plan to user (for visibility)
- Track plan file path in session constants for phase briefs
- Proceed to Stage 1 (RED-GREEN-REFACTOR loop)

*Note: User can Ctrl+C to abort if plan needs adjustment.*
