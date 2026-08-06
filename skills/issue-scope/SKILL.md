---
name: issue-scope
disable-model-invocation: false
description: >
  Brainstorm features into scoped implementation plans with test decomposition.
  Socratic questioning, parallel codebase exploration and a coverage check
  produce a plan file compatible with /tdd, plus an ADR when the architectural
  decision warrants recording. When the work is too big for one plan, an
  INVEST/SPIDR gate splits it into a GitHub epic with linked child issues and a
  derived dependency graph. Invoke explicitly with /issue-scope.
---

# Issue Scope

```
1 Input → 2 Explore → 3 Brainstorm → 4 Approaches → 5 Decompose → 7 Check → 8 Write Plan
                                                          └─ 6 Epic Escape Hatch (branch, ends the run)
```

Produces a `docs/plans/YYYY-MM-DD-<feature>.md` that `/tdd` consumes directly — format and contract in [references/plan-format.md](references/plan-format.md).

When the work turns out to be too big for one plan, **Phase 6** splits it into a GitHub epic with linked child issues instead of producing a plan nobody can execute.

Inspired by [Superpowers](https://github.com/obra/superpowers) methodology: plans should be "clear enough for an enthusiastic junior engineer with poor taste and no judgement" to execute.

**Reason directly.** This skill used to route Phases 4 and 5 through the Sequential Thinking MCP. It no longer does — on a current model that mostly serialises reasoning you do better internally, and bills for the transcript. Think, then present the conclusion. The approaches and the slices are the output; the deliberation isn't.

**This skill does not use plan mode, deliberately.** Plan mode is a permission state that ends at one approval and hands off to implementation in the same conversation. `/issue-scope` produces a durable artefact for a *later* `/tdd` session, and `EnterPlanMode` causes the context amnesia `/tdd` already documents — exiting it loses the skill. Never enter plan mode from inside this skill. Phases 1–5 write nothing to disk; the only files this skill creates are the plan, the ADR, and (in Phase 6) GitHub issues.

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

Spawn **four Explore agents concurrently** — all four in a single message, `subagent_type="Explore"`, thoroughness `"very thorough"`. One agent per lens.

Four narrow agents beat one broad one here, and cost the same wall-clock. Each is blind to what the others find, so none of them quietly decides a concern is covered; and a single agent given six unrelated objectives reliably shortchanges the last two.

| Lens | Find |
|---|---|
| **Architecture & patterns** | Relevant files and modules · file structure, naming and architecture conventions · integration points · similar features to use as templates |
| **Test infrastructure** | The session constants below · test helpers and fixtures · E2E command, directory and auth fixture · **which existing tests already cover this area** |
| **Data & contracts** | Database schema (use Supabase MCP) · migrations · RLS policies · types and API surface the feature touches |
| **Prior art & constraints** | **Existing ADRs** — `docs/adr/`, `docs/decisions/` or `doc/adr/`: which constrain this feature, and would any be superseded? · git history and closed PRs/issues for this area · **the binding rules in the project `CLAUDE.md` and `~/.claude/rules/`** |

**Session constants** (from the test-infrastructure lens; carried into the plan for TDD):

| Constant | Example |
|----------|---------|
| Test command | `pnpm vitest run --reporter=verbose` |
| Test file pattern | colocated `*.test.ts` or `tests/__tests__/` |
| Test helpers | `tests/helpers/isolated-test-household.ts` |

The **constraints** lens matters more than it looks. House rules like the `actions.ts`/`logic.ts` split, worker-scoped fixtures, or the ban on `any` change how the work decomposes. Discovered here they shape the slices; discovered later they're rework that `code-reviewer` finds after the code exists. Quote the rules that bind — don't paraphrase them.

**Use Context7 MCP** if the feature involves framework behavior (Next.js, Supabase, React, Tailwind).

### Validate & Classify

After all four agents return, reconcile their findings and present one curated summary to the user:
- Key files and modules discovered
- Existing patterns that apply
- Session constants found, and which existing tests already cover this area
- ADR convention (path and numbering), plus any existing ADRs this feature touches
- **Constraints** — the house rules from `CLAUDE.md` / `~/.claude/rules/` that bind this feature, quoted

If two lenses disagree, say so rather than silently picking one — a contradiction between what the schema says and what the tests assume is usually the most interesting thing exploration found.

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
to **Phase 6** if it fails on Small alone. Otherwise carry on — the honest call
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

Work out 2-3 genuinely distinct approaches. Reason it through directly — no Sequential Thinking pass.

For each approach, know:
- **Name** — short label
- **How it works** — 2-3 sentences
- **Trade-offs** — what it makes easy, what it makes hard
- **Fits existing patterns?** — reference what Explore found

**Present them with `AskUserQuestion`, using `preview`.** One option per approach, your recommendation first and labelled `(Recommended)`. This is a comparison, so make it comparable:

- `label` — the approach name
- `description` — the trade-off in one line, not a summary of how it works
- `preview` — a compact sketch of what this approach *looks like*: the file layout it produces, the data flow, or the shape of the key function. This is what makes the choice real rather than a wall of prose the user skims.

One `preview` per option — the UI shows the focused option's preview beside the list, so write each as if it stands alone:

```
  actions.ts (thin)
    └─ logic.ts
         └─ categoryTree.ts        ← tree assembled in TS

  one fetch, built in memory
  unit-testable without a database
  n+1 avoided
```

Keep it to a single question with `multiSelect: false` — previews don't render on multi-select.

**Lead with your recommendation and explain why. The user decides.** If they want a hybrid, clarify what that means concretely before moving on.

If there's genuinely only one sensible approach, say so in prose and skip the question — but still run the ADR check below before Phase 5.

### ADR check (always run)

Once the approach is settled, **explicitly decide whether this decision warrants an ADR.** Run this every time, including when there was only one viable approach and when the feature felt small. Decisions with long half-lives are cheap to make and expensive to reconstruct — that asymmetry is the whole reason to check.

**An ADR is warranted when any of these hold:**
- **Hard to reverse** — schema shape, source of truth, data ownership, auth model, public contract
- **Sets a precedent** future work will copy without re-deciding
- **A credible alternative was rejected** for reasons that won't be visible in the code
- **It constrains or supersedes an existing ADR** (Explore should have surfaced these)
- **Cross-cutting** — CI, test isolation, ports, deployment topology, external providers
- **Someone will ask "why is it like this?"** in six months and the code won't answer

**Skip the ADR when:**
- The choice just follows a pattern Explore already found
- It's local to one module and cheap to reverse
- It's a library/API usage detail the code makes self-evident
- An existing ADR already covers it — link that ADR from the plan instead

**Then use AskUserQuestion, leading with a recommendation:**

> "This decision [is / isn't] ADR-worthy because [reason]. What do you want?"
> — Write ADR-NNN alongside the plan | Extend/supersede existing ADR-NNN | No ADR

**The user decides** — same rule as approach selection. Record the outcome *either way* in the plan's Architecture section, including "no ADR, because [reason]", so the next session doesn't re-litigate it.

**If the repo has no ADR directory:** don't silently create one. Ask. A single local decision doesn't justify inventing a convention; the first genuinely cross-cutting one does.

**Numbering:** next number = highest existing + 1, but check for in-flight ADRs on other branches before claiming it:

```bash
git log --all --diff-filter=A --pretty=format: --name-only -- docs/adr \
  | grep -oE 'docs/adr/[0-9]+' | sort -u | tail -5
```

This finds ADRs added on *any* branch, not just the ones present in your working tree. Parallel worktrees each claiming "the next number" from `ls docs/adr` is how duplicate ADR numbers happen.

---

## Phase 5: Decompose

Break the chosen approach into ordered slices. Reason it through directly. If the decomposition feels genuinely tangled, that isn't a signal to reach for a thinking tool — it's usually Phase 6 telling you this is an epic.

Each slice = one RED-GREEN-REFACTOR cycle in TDD. Slices build on each other.

**Slice design rules:**
- Each delivers testable value (not "set up infrastructure")
- Vertical: touches all layers needed (DB → logic → API → UI) — not horizontal layers
- 3-7 slices typical. If >7, **stop and go to Phase 6** — that's a prompt to run the INVEST gate, not a verdict. The slices you just produced are the raw material for the split, not wasted work.
- First slice is the smallest thing that proves the core works
- Last slice handles edge cases and polish

**For each slice, decompose into individual test descriptions:**
- Test names should read as behavior specs: "returns 404 when household not found"
- Include test type (unit / integration / e2e / pgtap)
- Note what the test builds on

**State each slice as a behaviour delta, not an end state** — exactly one of `ADDED` / `MODIFIED` / `REMOVED`, describing what changes relative to the code that exists today. "Household creation validates names" makes the executor re-derive what's new; "MODIFIED — `createHousehold` now rejects a name already used in the household" doesn't. If a slice needs two markers, it's two slices. Full rationale in [references/plan-format.md](references/plan-format.md) §3.

**A `MODIFIED` or `REMOVED` slice must name the existing tests it breaks.** The test-infrastructure lens in Phase 2 found them. This is the thing the old format lost most often: the plan changes behaviour that three existing tests assert, never says so, and the executor can't tell a regression from an intended change. If you checked and there are none, say `none` — the word, so the user knows it was checked.

**Present to user for approval:**

```
Feature: [name]

Slice 1: [foundation — e.g., core validation logic]
  Type: unit | Builds on: nothing
  Delta: ADDED — callers can validate a category name before submitting
  Touches existing tests: none
  - [ ] returns valid result for normal input
  - [ ] rejects empty name
  - [ ] trims whitespace

Slice 2: [next layer — e.g., database operations]
  Type: integration | Builds on: Slice 1
  Delta: MODIFIED — createCategory now rejects a duplicate name in the same household
  Touches existing tests: tests/categories/create.test.ts (asserts the old permissive behaviour)
  - [ ] creates record and returns ID
  - [ ] returns error for duplicate name
  - [ ] enforces RLS — user can only access own data

Slice 3: [API endpoint]
  Type: integration | Builds on: Slice 2
  Delta: ADDED — the category can be created over HTTP
  Touches existing tests: none
  - [ ] POST returns 201 with valid payload
  - [ ] POST returns 400 for invalid payload
  - [ ] POST returns 404 when parent not found
```

**Wait for approval.** User may reorder, split, merge, or drop slices.

**If something is still unresolved, mark it — don't decide it.** Anything Phase 3 didn't settle and Phase 2 couldn't find becomes a `[NEEDS CLARIFICATION]` item naming the slice it blocks, carried into the plan's `## Open questions`. A guess is worse than an admission here, because `/tdd` will implement a plausible guess faithfully and nothing downstream flags it. This is not a way to dodge Phase 3 — if you can ask the user now, ask now.

---

## Phase 6: Epic Escape Hatch *(branch — replaces Phases 7-8)*

Not a step every run takes. Reached from Phase 2 (2+ independently shippable
capabilities) or Phase 5 (>7 slices). Neither is a verdict — both are prompts to
run the gate. A run that enters Phase 6 ends here; a run that doesn't skips
straight from Phase 5 to Phase 7.

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

**4. Carry the Phase 4 ADR verdict onto the epic.** No plan file is written here,
so the verdict has nowhere else to land — and epic-sized work is the most
ADR-worthy case there is, since every child inherits the decision without
re-deciding it. If the check said write one, write it now (`docs/adr/NNN-<slug>.md`,
format in Phase 8) and link it from the epic body. If it said no, record that and
why in the epic body. Either way the ADR belongs to the **epic**, not to any one
child.

Then hand back with the ready-now children and **stop**. Tell the user, verbatim:

> Epic `#<n>` created with `<k>` children. Run `/clear`, then `/issue-scope <child>`
> to scope the first one.

Same reasoning as Phase 8's stop: the epic and its issue bodies are the durable
artefact, and scoping a child in this session drags the whole epic-split
brainstorm along with it into work that only needs the child. Do not invoke
`/issue-scope` on a child yourself.

**Phase 6 ends the run — do not continue to Phase 7 or 8.** The epic and its
children are the deliverable. Children are scoped individually when picked up, so
no plan file is written here, for the epic or for any child.

---

## Phase 7: Coverage Check

Runs after the Phase 5 approval, **before** the file is written. Skipped only by
Phase 6, which ends the run.

Work through the checklist in [references/plan-format.md](references/plan-format.md) §5.
Every item is checkable against text already in this conversation or against the
filesystem — no judgement, no agent, no extra exploration.

The one that earns the phase: **every acceptance criterion from Phase 3 maps to
at least one test bullet.** A requirement that gets discussed in the brainstorm
and silently never becomes a slice is the single most common way these plans
fail, and it is invisible unless something checks for it.

**Fix what you find, now.** A coverage failure is not a follow-up — the whole
value is catching it while the reasoning is still in context. Deferring it to an
issue is just shipping a broken plan with a ticket attached.

**Report what you checked out loud, passes included.** A silent check is
indistinguishable from a skipped one, and this is exactly the kind of step that
decays into a claim.

**This is not the plan review.** `/tdd` Stage 0-review spawns `tdd-plan-reviewer`
(Opus, cold context) for *judgement* — testability, YAGNI, architectural fit.
This pass is *mechanical completeness*: did everything we agreed on actually make
it into the file. They catch different failures. Neither replaces the other.

---

## Phase 8: Write Plan

After the coverage check passes, write the plan file.

**File path:** `docs/plans/YYYY-MM-DD-<feature-slug>.md`

Use today's date. Slugify the feature name (lowercase, hyphens).

**Plan format:** [references/plan-format.md](references/plan-format.md) §2 — the
template, and §1, the `- [ ]` contract that governs it.

Read §1 before deviating from the template in any way. `/tdd` finds its next test
with a literal `- \[ \]` regex and treats **every** unchecked checkbox in the file
as a test to write, so open questions use `- [?]` and affected existing tests are
a plain line. Get that wrong and `/tdd` writes a test named after your question.

Beyond the old format, the plan now carries:
- `## Acceptance` — the one user-observable assertion that proves the feature, plus `User-facing: yes|no`. `/tdd` Stage 0f builds its acceptance test from this.
- `## Constraints` — the binding house rules Explore quoted
- `## Open questions` — `[NEEDS CLARIFICATION]` items, or `None.`
- Per slice: `Behaviour delta:` and `Touches existing tests:`

**If the ADR check approved one, write it too** — `docs/adr/NNN-<slug>.md`, matching the repo's existing ADR format. If there is no existing format, use:

```markdown
# ADR NNN: [decision, stated as a decision not a topic]

**Status:** Proposed
**Date:** YYYY-MM-DD
**Issue:** [#N](issue url) — if one exists
**Supersedes:** [ADR NNN](./NNN-slug.md) — if applicable

## Context
[The forces in play. What was true before, what problem it caused. Include the
Explore findings that constrained the choice.]

## Decision
[What we're doing, in the active voice.]

## Consequences
[What this makes easy, what it makes hard, what now has to be maintained.]

## Alternatives considered
[The approaches from Phase 4 that lost, and *why* — this is the part the code
can't tell you later.]
```

Status stays **Proposed** until the implementing PR merges, then flips to **Accepted**. Write it now rather than after implementation: the reasoning is freshest here, and it's the input `/tdd` needs, not an artefact of it.

**After writing the plan — this is where the run ends:**

1. Show the file path(s) to the user — plan, and ADR if written
2. **Do not invoke `/tdd`.** Do not offer to. The plan file is the complete
   handoff: `/tdd` Stage 0 opens with *"0-check: look for existing plan file in
   `docs/plans/*.md`"* and is designed to cold-start from it, re-exploring the
   codebase from scratch.
3. Tell the user, verbatim:

   > Plan written to `<path>`. Run `/clear`, then `/tdd <path>`.

**Why this is a stop and not an offer.** Everything this session accumulated —
the brainstorm, the Explore dumps, the approaches you considered and rejected —
is *input* that has already been distilled into the plan file. Carrying it into
TDD costs roughly 200k tokens and buys nothing the plan does not already say.
Measured across 484 sessions: `/tdd` alone peaks at a 131k mean, `issue-scope` +
`tdd` + `ship` in one session peaks at **537k**. Context rot makes those tokens
actively harmful, not merely expensive — quality degrades with absolute input
length long before the window fills.

You cannot type `/clear` yourself; there is no tool for it. So the stop is a
stop-and-instruct, and the instruction has to be the last thing you say.

---

## Rules

- **Never skip brainstorming.** Even if the user provides a detailed spec, ask at least 2-3 clarifying questions. Hidden assumptions are the #1 source of rework.
- **Never start with infrastructure.** Slice 1 must deliver testable behavior, not "create database table" or "set up project structure."
- **Challenge scope creep.** If a slice has >5 tests, it probably needs splitting.
- **Respect existing patterns.** Explore findings override theoretical "best practices."
- **Trade-offs are explicit.** The user makes architectural decisions, not the AI.
- **Never produce a plan you know is too big.** An 11-slice plan is not a plan, it's a backlog with no issue numbers. Go to Phase 6 — the thinking is kept, not thrown away.
- **An epic is not the answer to "unclear".** It's the answer to "clear but too big". The INVEST gate is what tells the two apart; don't skip it because the feature obviously feels large.
- **Always run the ADR check.** Every run reaches a verdict — "ADR-NNN" or "no ADR, because…" — recorded in the plan or the epic. Silently not considering it is the failure mode; deciding against one is fine.
- **Never write a plan that fails its own coverage check.** Fix it in Phase 7, in context. A coverage failure filed as a follow-up is a broken plan with a ticket attached.
- **An unknown gets a marker, not an invented answer.** `[NEEDS CLARIFICATION]` naming the slice it blocks beats a plausible guess — `/tdd` implements guesses faithfully and nothing downstream catches them.
- **Say what changes, not what exists.** Every slice is an ADDED / MODIFIED / REMOVED delta, and every MODIFIED or REMOVED names the existing tests it breaks. A plan that silently invalidates existing tests hands the executor a red suite it can't interpret.
