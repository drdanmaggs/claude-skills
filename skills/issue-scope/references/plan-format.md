# Plan Format

The artefact `/tdd` consumes. Written by [SKILL.md](../SKILL.md) Phase 8, once
the coverage check in Phase 7 passes.

A plan is not a summary of the conversation. It is an instruction set for a
session that will never see the conversation — and, per the Superpowers rule
this skill is built on, for "an enthusiastic junior engineer with poor taste and
no judgement". Everything the next session needs must be *in the file*.

---

## 1. The `- [ ]` contract — read this before changing anything

`/tdd` finds its next test with a literal regex, `- \[ \]`, and processes the
plan strictly top-to-bottom. **Every unchecked checkbox in the file is a test it
will write.**

So only tests get `- [ ]`. Specifically:

| Thing | Syntax | Why |
|---|---|---|
| A test to write | `- [ ] returns 404 when household not found` | The contract |
| An open question | `- [?] Which table owns the FK? — blocks Slice 2` | `- [ ]` would make `/tdd` implement the question |
| An existing test that breaks | `Touches existing tests:` line on the slice | Same reason — it's already written |
| A constraint | Bullet under `## Constraints` | Not a unit of work |

Get this wrong and `/tdd` writes a test called "Which table owns the FK?".

---

## 2. Template

````markdown
# TDD Plan: [feature name]

## Context
[1-2 sentences: what problem this solves, why now]

## Acceptance
[The single end-to-end assertion that proves this feature works, stated in
user-observable terms. Not a unit test — the thing you'd demo.]

User-facing: yes | no

## Architecture
[2-3 sentences: chosen approach, key decisions made during brainstorming]

**Decision record:** [ADR-NNN](../adr/NNN-slug.md) — or "None: [why this decision doesn't need one]"

## Constraints
[Binding rules from the project's CLAUDE.md and ~/.claude/rules/ that this
feature must obey. Quote them; don't paraphrase. Omit rules that don't bind
this work.]

- `actions.ts` is a thin wrapper; testable logic lives in `logic.ts`
- Integration tests use worker-scoped fixtures, never manual `beforeAll`/`afterAll`
- No `any`. `unknown` + runtime validation at boundaries.

## Open questions
[Unresolved unknowns, as `- [?]`. Each names the slice it blocks. `/tdd` must
resolve one with the user before starting the slice it blocks — it must not
invent an answer.]

- [?] Does the existing `households` RLS policy already cover this read path? — blocks Slice 2

(or: `None.`)

## Session Constants
Test command: [from explore]
Test file pattern: [from explore]
Test helpers: [from explore]
E2E command / dir / auth fixture: [from explore, or "n/a"]

## Slice 1: [description]
Type: unit | Status: pending
Behaviour delta: ADDED — [what a user or caller can now do that they couldn't]
Files: [exact paths to create/modify]
Touches existing tests: none

- [ ] test description 1
- [ ] test description 2
- [ ] test description 3

## Slice 2: [description]
Type: integration | Status: pending
Behaviour delta: MODIFIED — [what changes about behaviour that already exists]
Files: [exact paths]
Builds on: Slice 1
Touches existing tests: tests/categories/create.test.ts (asserts the old duplicate-name behaviour)

- [ ] test description 1
- [ ] test description 2
````

---

## 3. Behaviour delta — say what changes, not what exists

Borrowed from [OpenSpec](https://openspec.dev/). `/issue-scope` is nearly always
brownfield — Phase 2 explored an existing codebase — so a slice described as an
end state makes the executor re-derive what's actually new.

| | |
|---|---|
| ✗ End state | "Household creation validates names" |
| ✓ Delta | `MODIFIED — createHousehold now rejects a name already used in the same household` |

Use exactly one of **ADDED** / **MODIFIED** / **REMOVED** per slice. If a slice
needs two, it's two slices.

**`MODIFIED` and `REMOVED` oblige you to fill in `Touches existing tests:`.**
This is the single biggest gap the old format had: a plan could change behaviour
that three existing tests assert, and never mention them — so the executor hits
red tests it didn't expect and can't tell a regression from an intended change.
Name the files. If you genuinely checked and there are none, write `none` — the
word, so the reader knows it was checked rather than skipped.

---

## 4. `[NEEDS CLARIFICATION]` — mark the unknown, don't fill it

Borrowed from [Spec Kit](https://github.com/github/spec-kit).

A plan that guesses is worse than a plan that admits it doesn't know, because
`/tdd` implements a plausible guess faithfully and nothing ever flags it. If
Phase 3 didn't settle something and Phase 2 couldn't find it, it goes in
`## Open questions` as `- [?]`, naming the slice it blocks.

Rules:

- **Every question names a blocked slice.** A question blocking nothing is a
  musing — drop it or fold it into Context.
- **A blocked slice does not start.** `/tdd` resolves the question with the user
  first.
- **Keep the section even when empty** (`None.`). Its absence should mean "this
  plan predates the format", not "nothing was unclear".

Don't use it to dodge Phase 3. If you can ask the user now, ask now — this is
for what survives the brainstorm, not a substitute for having one.

---

## 5. Coverage check

Adapted from Spec Kit's `/analyze`. Run in Phase 7, **before** the file is
written. Every item is checkable against text already in the conversation or
against the filesystem — no judgement calls, no agent needed.

| Check | What a failure means |
|---|---|
| Every acceptance criterion from Phase 3 maps to ≥1 test bullet | A requirement vanished between brainstorm and decomposition. This is the classic failure and the reason the pass exists. |
| `## Acceptance` is a user-observable assertion, not a restatement of the title | `/tdd` Stage 0f has nothing to build an acceptance test from |
| Every `Builds on:` names an earlier slice in *this* plan | Dangling reference; `/tdd` runs top-to-bottom regardless and breaks |
| Every `Files:` path exists, or is new with an existing parent directory matching project convention | Hallucinated path — `app/lib/` in a repo that uses `src/lib/` |
| No test description appears in two slices | Duplicate work; `/tdd` writes it twice |
| Every `MODIFIED`/`REMOVED` slice has a `Touches existing tests:` entry or an explicit `none` | Silent regression |
| Every `## Constraints` entry is satisfied by the slices, or explicitly waived with a reason | A standards violation planned in from the start |
| Every `- [?]` names the slice it blocks | Unresolvable marker |
| No `- [ ]` outside a slice's test list | Breaks the `/tdd` contract in §1 |

**Fix failures now; do not file them.** The whole value is catching them while
the reasoning is still in context — a coverage failure deferred to an issue is
just a broken plan with a ticket attached.

Report what was checked out loud, including the passes. A silent check is
indistinguishable from a skipped one.

### This is not the plan review

`/tdd` Stage 0-review spawns `tdd-plan-reviewer` (Opus, cold context) for
*judgement* — is this testable, is it YAGNI, does it fit the architecture. This
pass is *mechanical completeness*: did everything we agreed on actually make it
into the file.

They catch different failures and neither substitutes for the other. Don't
collapse them.
