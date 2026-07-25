# GitHub Issue Relationships — GraphQL API Reference

## Dependencies (Blocked-by / Blocking)

### Add dependency

```bash
gh api graphql -f query='
  mutation {
    addBlockedBy(input: {
      issueId: "I_kwDOQWdX4c7jHKJB"       # blocked issue
      blockingIssueId: "I_kwDOQWdX4c7jHLSr"  # blocking issue
    }) {
      issue { number title }
      blockingIssue { number title }
    }
  }
'
```

### Remove dependency

```bash
gh api graphql -f query='
  mutation {
    removeBlockedBy(input: {
      issueId: "I_kwDOQWdX4c7jHKJB"
      blockingIssueId: "I_kwDOQWdX4c7jHLSr"
    }) { issue { number } }
  }
'
```

### GitHub UI effects

- "Blocked" badge on blocked issues
- Relationships shown in issue sidebar
- Filter with `is:blocked`, `is:blocking`, `blocked-by:#123`, `blocking:#456`

---

## Parent-Child Relationships (Epics)

**Always include `-H "GraphQL-Features: sub_issues"` — without it the mutation fails silently.**

### Add child to parent

```bash
gh api graphql \
  -H "GraphQL-Features: sub_issues" \
  -f query='
  mutation {
    addSubIssue(input: {
      issueId: "PARENT_NODE_ID"
      subIssueId: "CHILD_NODE_ID"
    }) {
      issue { number title }
      subIssue { number title }
    }
  }
'
```

### Remove child from parent

```bash
gh api graphql \
  -H "GraphQL-Features: sub_issues" \
  -f query='
  mutation {
    removeSubIssue(input: {
      issueId: "PARENT_NODE_ID"
      subIssueId: "CHILD_NODE_ID"
    }) { issue { number } }
  }
'
```

### Query sub-issues

**Summary (progress):**
```bash
gh api graphql \
  -H "GraphQL-Features: sub_issues" \
  -f query='
  query {
    repository(owner: "owner", name: "repo") {
      issue(number: 313) {
        subIssuesSummary { total completed percentCompleted }
      }
    }
  }
'
```

**List sub-issues:**
```bash
gh api graphql \
  -H "GraphQL-Features: sub_issues" \
  -f query='
  query {
    repository(owner: "owner", name: "repo") {
      issue(number: 313) {
        subIssues(first: 10) { nodes { number title state } }
      }
    }
  }
'
```

**Get parent of an issue:**
```bash
gh api graphql \
  -H "GraphQL-Features: sub_issues" \
  -f query='
  query {
    repository(owner: "owner", name: "repo") {
      issue(number: 314) {
        parent { number title }
      }
    }
  }
'
```

### GitHub UI effects

- Progress indicator on parent: "X of Y tasks complete"
- "Sub-issues" section in sidebar
- "Parent issue" link on child issues
- Nested visualization in project boards

---

## Combining Both Features

Use parent-child for hierarchy, dependencies for execution order:

```bash
# Parent-child (epic structure)
gh api graphql -H "GraphQL-Features: sub_issues" -f query="
  mutation {
    s1: addSubIssue(input: {issueId: \"$epic_id\", subIssueId: \"$phase1_id\"}) { issue { number } }
    s2: addSubIssue(input: {issueId: \"$epic_id\", subIssueId: \"$phase2_id\"}) { issue { number } }
    s3: addSubIssue(input: {issueId: \"$epic_id\", subIssueId: \"$phase3_id\"}) { issue { number } }
  }
"

# Dependencies (execution order: phase1 → phase2 → phase3)
gh api graphql -f query="
  mutation {
    d1: addBlockedBy(input: {issueId: \"$phase2_id\", blockingIssueId: \"$phase1_id\"}) { issue { number } }
    d2: addBlockedBy(input: {issueId: \"$phase3_id\", blockingIssueId: \"$phase2_id\"}) { issue { number } }
  }
"
```

---

## Getting Node IDs

Issue numbers are human-readable (`#562`). GraphQL requires node IDs (`I_kwDO...`). Batch lookups:

```bash
gh api graphql -f query='
  query {
    repository(owner: "OWNER", name: "REPO") {
      a: issue(number: 562) { id number title }
      b: issue(number: 563) { id number title }
    }
  }
' | jq '.data.repository'
```

Or using shell variables:

```bash
get_node_id() {
  local owner=$1 repo=$2 num=$3
  gh api graphql -f query="
    query {
      repository(owner: \"$owner\", name: \"$repo\") {
        issue(number: $num) { id }
      }
    }
  " | jq -r '.data.repository.issue.id'
}

issue_id=$(get_node_id "myorg" "myrepo" 562)
```

---

## Troubleshooting

**"Could not resolve to a node with the global id"**
→ Node ID is wrong. Re-fetch it — node IDs always start with `I_kwDO`.

**Mutation returns no error but nothing changed (parent-child)**
→ Missing `-H "GraphQL-Features: sub_issues"` header.

**`gh` CLI has no `--blocked-by` flag**
→ Known gap, tracked at [cli/cli#11757](https://github.com/cli/cli/issues/11757). Use GraphQL workaround above.
