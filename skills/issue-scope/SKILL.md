---
name: issue-scope
disable-model-invocation: false
description: >
  Brainstorm features into scoped implementation plans with test decomposition.
  Socratic questioning, codebase exploration, and Sequential Thinking produce
  a plan file compatible with /tdd. When the work is too big for one plan, an
  INVEST/SPIDR gate splits it into a GitHub epic with linked child issues and a
  derived dependency graph. Invoke explicitly with /issue-scope.
---

# Issue Scope

Brainstorm → Explore → Question → Approach → Decompose → Plan. Produces a `docs/plans/YYYY-MM-DD-<feature>.md` that `/tdd` consumes directly.

When the work turns out to be too big for one plan, **Phase 5.5** splits it into a GitHub epic with linked child issues instead of producing a plan nobody can execute.

Inspired by [Superpowers](https://github.com/obra/superpowers) methodology: plans should be "clear enough for an enthusiastic junior engineer with poor taste and no judgement" to execute.

---

## Phase 1: Input

Accept one of:
- **GitHub issue URL/number** — read with `gh issue view` (include comments)
- **User description** — free text about what they want
- **Existing notes** — file path to prior thinking

If a GitHub issue exists, read it fully — but still confirm understanding in Phase 3.

If the user provides no input, ask: "What do you want to build?"

---

## Phase 2: Explore

Spawn **Explore agent** (`subagent_type="Explore"`, thoroughness `"very thorough"`).

Find:
- Relevant files and modules for this feature
- Existing patterns (file structure, naming, architecture conventions)
- Dependencies and integration points
- Similar features/tests to use as templates
- Database schema if relevant (use Supabase MCP)

**Also discover session constants** (carried into the plan for TDD):

| Constant | Example |
|----------|---------|
| Test command | `pnpm vitest run --reporter=verbose` |
| Test file pattern | colocated `*.test.ts` or `tests/__tests__/` |
| Test helpers | `tests/helpers/isolated-test-household.ts` |

**Use Context7 MCP** if the feature involves framework behavior (Next.js, Supabase, React, Tailwind).

### Validate & Classify

After exploration, present a curated findings summary to the user:
- Key files and modules discovered
- Existing patterns that apply
- Session constants found

Then use **AskUserQuestion**: "Does this match your understanding of the landscape? Anything I missed?"

**Classify scope size:**

| Size | Signal | Action |
|------|--------|--------|
| **Small** | 1-2 files, well-understood pattern | Proceed normally |
| **Medium** | 3-5 files, clear integration points | Proceed normally |
| **Large** | 6+ files, cross-cutting, or unfamiliar domain | Proceed, but re-check at Phase 5 |

This table is a rough read on volume, and volume is **not** what makes something
an epic — a 12-file rename isn't one, a 3-file feature spanning two unshipped
capabilities is. If the feature looks like it covers 2+ independently shippable
capabilities, apply the INVEST gate in
[references/splitting-framework.md](references/splitting-framework.md) now and go
to **Phase 5.5** if it fails on Small alone. Otherwise carry on — the honest call
usually comes after decomposition, when you can see what the work actually is.

**Spike detection:** If Explore reveals significant unknowns (unfamiliar library, unclear DB design, undocumented external API), offer a **spike plan** instead of a full plan:

```
Spike: Investigate [what's unknown]
Time-box: [30 min / 1 hour]
Questions to answer:
- [specific question 1]
- [specific question 2]
Output: Findings that unblock full scoping
```

If user accepts the spike, write it to `docs/plans/YYYY-MM-DD-spike-<topic>.md` and end. If user says "I know enough, proceed anyway", continue to Phase 3.

This is the **INVEST-Estimable** route, and it is SPIDR's `S`. A feature you
can't size isn't an epic — splitting it just produces several features you can't
size. Spike first, then re-scope.

---

## Phase 3: Brainstorm (Socratic Questioning)

**One question at a time. Multiple choice where possible.**

Use **AskUserQuestion** for each. The goal is to surface hidden requirements and cut unnecessary scope.

Question categories (ask what's relevant, skip what's obvious):

1. **What does "working" look like?** — acceptance criteria, user perspective
2. **What's the scope?** — MVP vs full feature, what's explicitly OUT
3. **Constraints?** — existing patterns to follow, DB schema decisions, performance needs
4. **Test types?** — unit only? integration? E2E? pgTAP?
5. **Edge cases that worry you?** — things the user already knows are tricky

**YAGNI ruthlessly.** If the user describes something that sounds like a future concern, challenge it: "Do we need this for the first version, or can it be a follow-up?"

**Stop asking when:**
- You understand the acceptance criteria
- You know what's in and out of scope
- You can distinguish between the approaches

Typically 3-6 questions. Never more than 8.

---

## Phase 4: Approaches

Use **Sequential Thinking** (`mcp__sequential-thinking__sequentialthinking`) to analyze 2-3 approaches.

For each approach, present:
- **Name** — short label
- **How it works** — 2-3 sentences
- **Trade-offs** — pros and cons
- **Fits existing patterns?** — reference what Explore found

**Lead with your recommendation and explain why.** The user decides.

Present in a clear format:

```
### Approach A: [name] (Recommended)
[How it works]
+ [Pro]
+ [Pro]
- [Con]

### Approach B: [name]
[How it works]
+ [Pro]
- [Con]
- [Con]
```

**Wait for user to choose.** If they want a hybrid, clarify what that means concretely.

If there's genuinely only one sensible approach, say so and skip to Phase 5.

---

## Phase 5: Decompose

Use **Sequential Thinking** to break the chosen approach into ordered slices.

Each slice = one RED-GREEN-REFACTOR cycle in TDD. Slices build on each other.

**Slice design rules:**
- Each delivers testable value (not "set up infrastructure")
- Vertical: touches all layers needed (DB → logic → API → UI) — not horizontal layers
- 3-7 slices typical. If >7, **stop and go to Phase 5.5** — that's a prompt to run the INVEST gate, not a verdict. The slices you just produced are the raw material for the split, not wasted work.
- First slice is the smallest thing that proves the core works
- Last slice handles edge cases and polish

**For each slice, decompose into individual test descriptions:**
- Test names should read as behavior specs: "returns 404 when household not found"
- Include test type (unit / integration / e2e / pgtap)
- Note what the test builds on

**Present to user for approval:**

```
Feature: [name]

Slice 1: [foundation — e.g., core validation logic]
  Type: unit | Builds on: nothing
  - [ ] returns valid result for normal input
  - [ ] rejects empty name
  - [ ] trims whitespace

Slice 2: [next layer — e.g., database operations]
  Type: integration | Builds on: Slice 1
  - [ ] creates record and returns ID
  - [ ] returns error for duplicate name
  - [ ] enforces RLS — user can only access own data

Slice 3: [API endpoint]
  Type: integration | Builds on: Slice 2
  - [ ] POST returns 201 with valid payload
  - [ ] POST returns 400 for invalid payload
  - [ ] POST returns 404 when parent not found
```

**Wait for approval.** User may reorder, split, merge, or drop slices.

---

## Phase 5.5: Epic Escape Hatch

Reached from Phase 2 (2+ independently shippable capabilities) or Phase 5 (>7
slices). Neither is a verdict — both are prompts to run the gate.

**1. Run the INVEST gate** — [references/splitting-framework.md](references/splitting-framework.md) §1.

The rule that decides it: **fails on anything other than Small → fix that first,
don't split. Fails on Small alone → split.** An unclear feature split into five
becomes five unclear features. Failing on Estimable means spike (Phase 2), not
epic; failing on Valuable or Testable means back to Phase 3.

**2. Spawn `epic-splitter`** (`subagent_type: epic-splitter`, model opus) with:

- the **absolute path** to `references/splitting-framework.md` — resolve it from
  this skill's own location. The agent runs inside the user's project, where a
  path relative to this repo means nothing, and it will stop rather than guess
  at the criteria.
- the approved decomposition from Phase 5
- the Phase 2 exploration findings
- the project repo path

By this point your own context is saturated with the brainstorm, which biases
toward "these slices are basically fine". The agent reads cold, works out the
children and the cut lines, and derives the dependency graph with evidence for
every edge. It is allowed to come back with **"not an epic"** — that is a real
answer, take it.

**3. Follow [references/epic-split.md](references/epic-split.md)** — present the
verdict, get approval, create the epic and children via `issue-labeller`, link
them via `github-issue-relationships`, and **verify the links took**
(`addSubIssue` fails silently without its header).

Then hand back with the ready-now children and offer `/issue-scope <child>`.

**Phase 5.5 ends the run — do not continue to Phase 6.** The epic and its
children are the deliverable. Children are scoped individually when picked up, so
no plan file is written here, for the epic or for any child.

---

## Phase 6: Write Plan

After user approves, write the plan file.

**File path:** `docs/plans/YYYY-MM-DD-<feature-slug>.md`

Use today's date. Slugify the feature name (lowercase, hyphens).

**Plan format:**

```markdown
# TDD Plan: [feature name]

## Context
[1-2 sentences: what problem this solves, why now]

## Architecture
[2-3 sentences: chosen approach, key decisions made during brainstorming]

## Session Constants
Test command: [from explore]
Test file pattern: [from explore]
Test helpers: [from explore]

## Slice 1: [description]
Type: unit | Status: pending
Files: [exact paths to create/modify]

- [ ] test description 1
- [ ] test description 2
- [ ] test description 3

## Slice 2: [description]
Type: integration | Status: pending
Files: [exact paths]
Builds on: Slice 1

- [ ] test description 1
- [ ] test description 2
```

**After writing the plan:**

1. Show the file path to the user
2. Offer handoff: "Ready to start TDD? I can invoke `/tdd` which will pick up this plan."
3. If user says yes, invoke `/tdd` via Skill tool
4. If user says no, end gracefully — plan is saved for later

---

## Rules

- **Never skip brainstorming.** Even if the user provides a detailed spec, ask at least 2-3 clarifying questions. Hidden assumptions are the #1 source of rework.
- **Never start with infrastructure.** Slice 1 must deliver testable behavior, not "create database table" or "set up project structure."
- **Challenge scope creep.** If a slice has >5 tests, it probably needs splitting.
- **Respect existing patterns.** Explore findings override theoretical "best practices."
- **Trade-offs are explicit.** The user makes architectural decisions, not the AI.
- **Never produce a plan you know is too big.** An 11-slice plan is not a plan, it's a backlog with no issue numbers. Go to Phase 5.5 — the thinking is kept, not thrown away.
- **An epic is not the answer to "unclear".** It's the answer to "clear but too big". The INVEST gate is what tells the two apart; don't skip it because the feature obviously feels large.
