# Close Comment Templates

When closing issues, add a comment explaining why. This preserves context for anyone reviewing closed issues later.

## Template

```
**Triaged by issue-triage** — closing with explanation.

**Reason:** {reason_category}

{detail}

If this was closed in error, reopen with additional context about why the issue is still relevant.
```

## Reason Categories

### Already Resolved
```
**Reason:** Already resolved

The problem described in this issue was addressed in {commit/PR reference}. Verified that {file} no longer contains the described issue.
```

### Stale — Code Changed
```
**Reason:** Stale — referenced code has changed

The file(s) referenced in this issue ({files}) have been significantly modified or removed since this issue was created. The original concern no longer applies to the current codebase.
```

### Handled Elsewhere
```
**Reason:** Handled by existing infrastructure

Investigated and found this is handled by {middleware/framework/parent component/etc}. Specifically: {brief explanation of how it's handled}.
```

### Speculative — No Evidence
```
**Reason:** YAGNI — no evidence of real impact

This issue describes a potential improvement without evidence of actual problems. No bugs, errors, or user reports related to this concern were found. Can be reopened if evidence surfaces.
```

### Unpredictable Scope
```
**Reason:** Unpredictable scope — not actionable as written

The described change ("{ issue title}") has unclear boundaries and would likely cascade beyond the initial estimate. If this becomes a priority, it should be re-scoped into specific, bounded tasks.
```

### Duplicate / Overlapping
```
**Reason:** Overlaps with #{other_issue_number}

This issue describes a concern that overlaps with #{other_issue_number}. Consolidating discussion there.
```

## Guidelines

- Be specific — reference actual files, commits, code locations
- Be respectful — the issue was created in good faith
- Provide reopening criteria — "reopen if X happens"
- Keep it brief — 2-4 sentences max
