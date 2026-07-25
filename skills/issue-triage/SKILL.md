---
name: issue-triage
description: >
  Evaluate GitHub issues against the actual codebase to determine if they're worth keeping.
  Applies YAGNI-style evaluation with parallel subagent verification — checks if referenced
  code still exists, if problems were already fixed, and if suggestions are speculative vs real.
  Use when the backlog feels noisy, after bulk issue creation from code reviews, or to audit
  tech debt issues. Replaces tidy-issues. Auto-triggers on: "triage issues", "review backlog",
  "clean up issues", "audit tech debt", "are these issues still relevant".
allowed-tools: Read Grep Glob Task Bash(gh issue:*) Bash(gh api:*) Bash(git log:*)
---

# Issue Triage

Evaluate GitHub issues against codebase reality. Close what's stale, speculative, or already fixed. Keep what's real and actionable. Every open issue is cognitive tax — make it earn its place.

**Architecture:** Two-phase funnel. Sonnet screens fast (50 concurrent), sonnet deep-evaluates survivors.

---

## Stage 1: Fetch Issues

Determine scope from user input or default to all open issues.

```bash
# Default: all open issues (paginate if needed)
gh issue list --state open --json number,title,body,labels,createdAt,author --limit 200

# With label filter
gh issue list --label "tech-debt" --state open --json number,title,body,labels,createdAt,author

# Single issue (skips straight to Stage 3)
gh issue view {number} --json number,title,body,labels,createdAt,author,comments
```

**Quick filter** — exclude before screening:
- Labels: `enhancement`, `feature` (feature requests)
- Issues with milestones assigned
- Issues created in the last 7 days

Report: "Found {N} issues. Screening in batches of 50."

---

## Stage 2: Screen (sonnet, 50 concurrent)

Verify each issue against current codebase state. Resolve as many as possible — use sequential thinking for marginal cases rather than deferring.

Launch **50 concurrent sonnet Task agents** per batch. For 150 issues = 3 batches.

### Screening Subagent Brief

```
subagent_type: general-purpose
model: sonnet
description: "Screen: #{number}"
```

**Prompt:**

```
Screen this GitHub issue against the current codebase. Resolve the verdict yourself where possible.

Issue #{number}: {title}
Body: {body}
Created: {created_at}

Steps:
1. Extract file paths from the issue body
2. Check if those files still exist (use Glob)
3. If files exist: run git log --since="{created_at}" --oneline -- {files}
   to check if the code was modified since the issue was created
4. Check for auto-close language patterns:
   - "Consider adding...", "Might benefit from...", "Could potentially..."
   - "Add comprehensive...", "Implement full...", "Refactor entire..."
   - "Performance optimisation" with no evidence of actual problem
   - No specific file or code location referenced at all
5. If the verdict isn't clear-cut, use sequential thinking
   (mcp__sequential-thinking__sequentialthinking) to reason through it.
   Consider: is this a real problem or speculative? Does the code context
   resolve the ambiguity? Arrive at a verdict — don't punt unless genuinely
   unable to determine.

Return ONE of:
- OBVIOUS_CLOSE: {reason} — file gone, already fixed, or speculative language
- OBVIOUS_KEEP: {reason} — security issue, verified bug, specific crash risk
- MARGINAL → resolved via sequential thinking: CLOSE|KEEP {reasoning}
- NEEDS_EVALUATION: {summary_of_what_to_check} — genuinely can't determine
```

**Expected outcome:** ~60-70% screen as OBVIOUS_CLOSE. Remainder flows to Stage 3.

Report: "Screened {N} issues. {close_count} obvious closes, {keep_count} obvious keeps, {eval_count} need deeper evaluation."

---

## Stage 3: Deep Evaluate (sonnet, 50 concurrent)

Only issues that passed screening as NEEDS_EVALUATION (plus OBVIOUS_KEEP for confirmation).

Launch **up to 50 concurrent sonnet Task agents** — typically one batch handles all survivors.

### Evaluation Subagent Brief

```
subagent_type: general-purpose
model: sonnet
description: "Evaluate: #{number} {short_title}"
```

**Prompt:**

```
Evaluate this GitHub issue against the actual codebase.

Read `~/.claude/skills/issue-triage/references/evaluation-criteria.md` first.

Issue #{number}: {title}
Body: {body}
Created: {created_at}
Labels: {labels}
Screening note: {screening_summary_from_stage_2}

Steps:
1. Read the referenced files and surrounding code
2. Verify: is the described problem still present?
3. If "missing X handling": grep for X in middleware, framework, parent components
4. Apply YAGNI evaluation from evaluation-criteria.md
5. Score confidence (0-100)
6. If 50-79%: use sequential thinking (mcp__sequential-thinking__sequentialthinking)
   to reason through execution paths and framework guarantees
7. Return verdict in the format from evaluation-criteria.md
```

---

## Stage 4: Present Triage

Merge all results: Stage 2 obvious closes + Stage 3 deep evaluations.

Before presenting, check for **overlap**: if two KEEP issues reference the same files/functions, flag as potential merge.

### Output Format

```
KEEP ({count}):
- #{number}: {title} ({confidence}%) — {reasoning}

CLOSE ({count}):
- #{number}: {title} ({confidence}% close) — {close_reason}

POTENTIAL OVERLAPS:
- #{a} and #{b} both reference {file/function} — consider merging

BORDERLINE (sequential thinking applied):
- #{number}: (initially {score}%) → {KEEP|CLOSE}: {conclusion}

Summary: {keep_count} keep, {close_count} close out of {total} evaluated
Screened out in Phase 1: {obvious_close_count}
```

**Use TodoWrite** to create the action plan. **Wait for user approval.**

---

## Stage 5: Execute Approved Actions

For each approved CLOSE:
1. Comment using templates from [close-reasons.md](references/close-reasons.md)
2. Close: `gh issue close {number} --comment "{close_comment}"`

For approved MERGES:
1. Comment on the duplicate referencing the surviving issue
2. Close the duplicate

For KEEP issues (optional):
- Re-label if the user requests (e.g., priority labels)

Report: "Closed {N} issues, kept {M}. Backlog reduced by {percentage}%."
