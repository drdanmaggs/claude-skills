---
name: github-issue-relationships
description: "Manage GitHub issue dependency links (blocked-by/blocking) and parent-child relationships (epics with child issues). Use when linking issues together, setting up blocked-by/blocking dependencies, organising issues under a parent epic, or removing these relationships. Triggers on: link issues, blocked by, blocking, depends on, parent issue, child issue, epic, issue dependencies, issue hierarchy, add sub-issue, parent-child."
---

# GitHub Issue Relationships

Two distinct relationship types — clarify which the user wants if not obvious:

| Type | Mutation | Purpose |
|------|----------|---------|
| **Dependencies** | `addBlockedBy` | Sequencing — "A must complete before B" |
| **Parent-child** | `addSubIssue` | Hierarchy — "epic contains child issues" |

Both use `gh api graphql`. The `gh` CLI has no native commands for either as of early 2026.

## Workflow

### 1. Clarify (if needed)

- Which issues? (numbers)
- Which repo? (owner/name) — infer from `git remote` if in a repo
- Dependency or parent-child? Or both?

### 2. Get node IDs

Batch multiple issues in one query — always:

```bash
gh api graphql -f query='
  query {
    repository(owner: "OWNER", name: "REPO") {
      a: issue(number: 1) { id number title }
      b: issue(number: 2) { id number title }
      c: issue(number: 3) { id number title }
    }
  }
'
```

Extract `id` values (format: `I_kwDO...`).

### 3. Apply relationships

**Dependency** (B blocked by A):
```bash
gh api graphql -f query='
  mutation {
    addBlockedBy(input: {
      issueId: "NODE_ID_OF_B"
      blockingIssueId: "NODE_ID_OF_A"
    }) { issue { number } blockingIssue { number } }
  }
'
```

**Parent-child** (child under parent epic) — header is CRITICAL:
```bash
gh api graphql \
  -H "GraphQL-Features: sub_issues" \
  -f query='
  mutation {
    addSubIssue(input: {
      issueId: "NODE_ID_OF_PARENT"
      subIssueId: "NODE_ID_OF_CHILD"
    }) { issue { number } subIssue { number } }
  }
'
```

**Multiple at once** — use named mutations:
```bash
gh api graphql \
  -H "GraphQL-Features: sub_issues" \
  -f query='
  mutation {
    c1: addSubIssue(input: { issueId: "PARENT_ID", subIssueId: "CHILD1_ID" }) { issue { number } }
    c2: addSubIssue(input: { issueId: "PARENT_ID", subIssueId: "CHILD2_ID" }) { issue { number } }
  }
'
```

### 4. Confirm

Report the linked issue numbers to the user.

## Critical Rules

- Parent-child REQUIRES `-H "GraphQL-Features: sub_issues"` — missing it fails silently
- Always batch node ID lookups into one GraphQL query
- `issueId` = the blocked/child issue; `blockingIssueId`/`subIssueId` = the blocker/parent

## Reference

Read `references/graphql-api.md` for: removing relationships, querying existing ones, combining both types, and troubleshooting.
