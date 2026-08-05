# Epic Split — Procedure

What to do once `epic-splitter` has returned its verdict. The criteria live in
[splitting-framework.md](splitting-framework.md); this file is the operational
half — presenting, creating, linking, verifying.

**Nothing here runs before the gate passes.** If the verdict is "Not an epic",
follow the route it names (spike, or back to Phase 3) and stop.

---

## 1. Present the verdict

Show the user:

- The **gate result** — which INVEST criteria failed, and why that means "split"
  rather than "spike" or "clarify"
- The **children**, each with its cut line and what it ships on its own
- The **dependency graph** — ready-now children first, then blocked ones with the
  evidence for each edge
- Any **warnings**

Then ask for approval. The user may re-cluster, correct edges, rename children,
or reject the epic entirely and continue with a single scoped issue. All are
valid — the verdict is analysis, not a decision.

**Do not create anything until they approve.** Issues are cheap to create and
annoying to unpick, and the hierarchy links make the unpicking worse.

---

## 2. Write the epic body

```markdown
## Problem

[What's broken or missing, and who is worse off for it. Not a solution summary.]

## Outcome

[What is true when every child has shipped.]

## Children

- [ ] #NN — [capability] *(ready)*
- [ ] #NN — [capability] *(ready)*
- [ ] #NN — [capability] *(blocked by #NN)*

## Sequencing

```
child-a ──┐
          ├──> child-c
child-b ──┘
```

[One line per edge stating the reason: "child-c queries the column child-a's
migration adds".]

## Out of scope

- [What this epic deliberately does not cover, and where it went instead]

---
Each child is scoped with `/issue-scope` when it is picked up. Plans are not
written up front — a plan written before the first child lands is stale by the
fourth.
```

GitHub renders sub-issue progress from the `addSubIssue` links, so the checklist
is for humans reading the body, not the source of truth for completion.

---

## 3. Create the issues

Delegate labelling to [issue-labeller](../../issue-labeller/SKILL.md) **Mode A**.

**Create the epic first** — its node ID is needed for every link.

### The epic's labels

The epic carries `epic` **plus exactly one type label**.

`epic` is a **reserved** name, not a type — see
[canon.yml](../../issue-labeller/references/canon.yml) and the matching warnings
in [github-issue-relationships](../../github-issue-relationships/SKILL.md) and
[issue-labeller](../../issue-labeller/SKILL.md). Applying `epic` alone leaves the
issue untyped, and `hooks/label-gate.sh` will reject the create.

```bash
gh issue create \
  --title "Epic: [capability]" \
  --label epic --label enhancement \
  --body-file - <<'EOF'
...
EOF
```

### The children

Each child gets its own type label on its own merits — they are not all
`enhancement` because the epic is. A child that only adds coverage is `test-gap`;
one that pays down design cost is `technical-debt`.

**Never apply `blocked` or `ready` labels.** Both are reserved and owned by
`issue-triage` and the Projects board. Dependency state comes from the
`addBlockedBy` link, which GitHub renders as a "Blocked" badge natively — a label
copy goes stale the moment a blocker closes.

Capture each issue number as you go; step 4 needs them all.

---

## 4. Link the hierarchy and dependencies

Delegate to [github-issue-relationships](../../github-issue-relationships/SKILL.md).

**Get all node IDs in one query** — epic and every child together.

**Parent-child** — batch as named mutations, and note the header:

```bash
gh api graphql \
  -H "GraphQL-Features: sub_issues" \
  -f query='
  mutation {
    c1: addSubIssue(input: { issueId: "EPIC_ID", subIssueId: "CHILD1_ID" }) { issue { number } }
    c2: addSubIssue(input: { issueId: "EPIC_ID", subIssueId: "CHILD2_ID" }) { issue { number } }
  }
'
```

**Dependencies** — only the evidenced edges from the verdict. Children in the
ready-now set get no `addBlockedBy` at all; that is what makes them findable with
`is:blocked` exclusions later.

```bash
gh api graphql -f query='
  mutation {
    d1: addBlockedBy(input: { issueId: "CHILD3_ID", blockingIssueId: "CHILD1_ID" }) { issue { number } }
  }
'
```

---

## 5. Verify the links took (MANDATORY)

**`addSubIssue` fails silently without `-H "GraphQL-Features: sub_issues"`** —
flagged twice in [graphql-api.md](../../github-issue-relationships/references/graphql-api.md).
A successful-looking mutation with no header leaves you an epic with no children
and no error. Query it back:

```bash
gh api graphql -H "GraphQL-Features: sub_issues" -f query='
  query { repository(owner: "OWNER", name: "REPO") {
    issue(number: EPIC) {
      subIssuesSummary { total completed }
      subIssues(first: 20) { nodes { number title } } } } }'
```

`total` must equal the number of children created. **If it is 0, the header was
dropped** — re-run step 4 with it and verify again. Do not report success on the
strength of the mutation not erroring.

---

## 6. Hand back

Report:

- The epic number and title
- Each child, with its state — ready now, or blocked by which
- The verified link count

Then offer the next step:

> Ready to start? `/issue-scope <first ready child>` will scope it properly.

If more than one child is ready, say so explicitly — that is the payoff for
doing the dependency analysis, and it is easy for the user to miss if the list
just reads as an ordered backlog.
