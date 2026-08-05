# Splitting Framework

The criteria for **whether** something must be split, **where** to cut it, and
**what makes a child good**. Single source of truth — read by
[SKILL.md](../SKILL.md) Phase 2 and 5.5, and by
[agents/epic-splitter.md](../../../agents/epic-splitter.md).

Volume is not the test. A 12-file rename is not an epic; a 3-file feature
spanning two unshipped capabilities is. Use the gate below, not a file count.

---

## 1. The gate — does this need splitting at all?

Assess the feature against **INVEST** ([Bill Wake](https://xp123.com/invest-in-good-stories-and-smart-tasks/)):

| | Criterion | Question |
|---|---|---|
| **I** | Independent | Could this be built without waiting on other unbuilt work? |
| **N** | Negotiable | Is the *what* settled, with the *how* still open? |
| **V** | Valuable | Can you name who is better off when it ships, and how? |
| **E** | Estimable | Do you understand the domain, schema and libraries well enough to size it? |
| **S** | Small | Does it fit in one PR that could merge on its own? |
| **T** | Testable | Are there observable acceptance criteria? |

**The decisive rule** ([Humanizing Work](https://www.humanizingwork.com/how-to-split-a-user-story-episode/)):

> **If it fails on anything other than Small — fix that first, don't split.
> If it fails *only* on Small, it's ready to split.**

Splitting an unclear feature produces several unclear features. It multiplies
the problem instead of solving it.

| Fails on | What it actually means | Route |
|---|---|---|
| **E**stimable | Unknown library, undecided schema, undocumented API | **Spike** — [SKILL.md § Spike detection](../SKILL.md). This is also SPIDR's `S`. Not an epic. |
| **V**aluable | Nobody can say who benefits | Back to Phase 3 brainstorming. Not an epic. |
| **N**egotiable | Arrived as a fixed solution with no stated problem | Back to Phase 3 — find the problem. Not an epic. |
| **T**estable | No observable acceptance criteria | Back to Phase 3 — get criteria. Not an epic. |
| **S**mall **only** | Well understood, just too big for one PR | **Split.** Continue to §2. |
| **S**mall + others | Big *and* unclear | Fix the others first, then re-run the gate. |

Record which criteria failed and why. The gate result is the justification for
the epic — an epic created without it is just a folder.

---

## 2. The cut lines — where to split

**SPIDR** ([Mike Cohn](https://www.mountaingoatsoftware.com/blog/five-simple-but-powerful-ways-to-split-user-stories)).
Each letter is a cut that yields pieces which **ship independently**, rather
than halves that only work together.

| | Cut | Use when | Example |
|---|---|---|---|
| **S** | Spike | One unknown is inflating the whole estimate | Split the "which queue library" research out; the rest is then estimable |
| **P** | Path | Users can achieve the goal several ways | Card payment first; Apple Pay second |
| **I** | Interface | Multiple surfaces or clients | Web first; mobile later. Or plain form first, drag-and-drop later |
| **D** | Data | Same operation across several data types or sources | Import CSV first; XLSX later |
| **R** | Rules | Pricing tiers, eligibility, validation, "flexible" anything | Simplest rule first; exceptions later |

**Prefer `R` and `D`.** They cut along behaviour, which keeps children vertical.
`I` is the most likely to produce a horizontal child — check it hard.

### Extended catalogue

When no SPIDR letter fits, use [Richard Lawrence's nine patterns](https://www.humanizingwork.com/how-to-split-a-user-story-episode/):
workflow steps · business rule variations · simple/complex · defer performance ·
major effort · interface variations · operations (CRUD) · variations in data ·
break out a spike.

Two that pull their weight often:

- **Operations (CRUD)** — triggered by verbs like *manage*, *configure*,
  *administer*. Split into Create / Read / Update / Delete. Read is usually the
  safest first child.
- **Workflow steps** — take one thin slice through the whole workflow first,
  then deepen. Not "step 1 fully, then step 2 fully".

**Always name the cut line used for each child.** A child whose cut line can't
be named was grouped by vibe, and is usually a layer.

---

## 3. The child test — is each piece any good?

Re-apply INVEST to every child. Two criteria do the real work:

**Valuable** — *could this merge to main on its own, tests green, and be worth
having?* If the honest answer is "not until its sibling lands too", it is not a
child; fold it into that sibling.

**Independent** — this is the dependency question (§4).

### Children are vertical, never layers

A `database` / `API` / `UI` split is the single most common failure at this
altitude. It is the same mistake [SKILL.md](../SKILL.md) already bans for slices,
and it fails the child test every time: a database child ships nothing a user
can have, and nothing can merge until all three land — which is one PR wearing
three issue numbers.

Name children as capabilities (*"export a plan as CSV"*), not as layers
(*"CSV export data layer"*).

**3-6 children.** Fewer than 3 and it probably wasn't an epic. More than 6 and
the cut line is too fine — or there are two epics.

---

## 4. Dependencies — what genuinely blocks what

**B is blocked by A only if B's tests cannot pass until A's artifact exists.**
A hard code, contract or schema dependency:

- B imports a module A creates
- B queries a column A's migration adds
- B calls an endpoint A defines

For every candidate edge, apply the **falsifying question**:

> *If A were never built, would B's tests still pass?*

**Yes → not a blocker.** Drop the edge.

Every surviving edge must cite the specific fact that justifies it, verified
against the codebase. An edge that can't be evidenced is a guess, and guessed
edges are worse than none — they park work that could have started today.

### These are not blockers

| Claim | Why it isn't |
|---|---|
| "B makes more sense after A" | Ordering preference. Sequence them in the epic body, don't block. |
| "A and B touch the same file" | Merge-conflict risk, resolved at rebase. Not a dependency. |
| "A matters more" | Priority — and there is no priority axis. See `no_priority` in [canon.yml](../../issue-labeller/references/canon.yml). |
| "B is polish for A" | If B's tests pass without A shipped, B isn't blocked. |
| "They're in the same epic" | Hierarchy is not sequencing. That's what `addSubIssue` is for. |

### Two smells

**All-chain.** Every child blocks the next. Almost always means the children came
out horizontal — re-cut before accepting it. A correct epic normally has 2+
children startable on day one.

**Cycle.** A blocks B and B blocks A ⇒ the boundary is wrong. Either merge the
two, or extract the shared piece into a third child that blocks both.

### Expressing it

Dependencies are recorded with `addBlockedBy` — GitHub renders the "Blocked"
badge and `is:blocked` filter from the link itself.

**Never write `blocked` or `ready` labels to express this.** Both are reserved in
[canon.yml](../../issue-labeller/references/canon.yml) and owned by `issue-triage`
and the Projects board. Duplicating the state into a label creates a second copy
that goes stale the moment a blocker closes.
