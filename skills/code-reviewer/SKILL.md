---
name: code-reviewer
description:
  Use this skill to review code. It supports both local changes (staged or working tree) and remote Pull Requests (by ID or URL). It focuses on correctness, maintainability, and adherence to project standards. Uses parallel review agents with a validation pass to deliver high-signal findings only.
allowed-tools: Read Grep Glob Task Bash(git diff:*) Bash(git log:*) Bash(git status:*) Bash(git rev-parse:*) Bash(gh pr checkout:*) Bash(gh pr view:*) Bash(gh api:*) Bash(gh issue view:*) Bash(git add:*) Bash(git commit:*)
---

# Code Reviewer

Orchestrate a multi-agent code review with auto-fix. Focus on what automated tools (lint, types, build) can't catch. HIGH SIGNAL ONLY — false positives erode trust.

## Step 1: Gather Context

**Remote PR** (user provides PR number/URL):
```bash
gh pr checkout <PR_NUMBER>
gh pr view <PR_NUMBER> --json title,body,files
```

**Check for uncommitted changes:**
```bash
git status --porcelain
```

- **Non-empty output** → `HAS_UNCOMMITTED=true`. Agents must run all three: `git diff` (unstaged) + `git diff --cached` (staged) + `git diff origin/main...HEAD` (committed).
- **Empty output** → `HAS_UNCOMMITTED=false`. Agents run `git diff origin/main...HEAD` only.

**Quick bail** — if ALL changed files match these patterns, report "No code to review" and stop:
- `*.md`, `*.mdx`, `*.json` (unless package.json deps changed), `*.lock`, `*.lockb`, `*.yml`, `*.yaml`

**Discover CLAUDE.md files** — find CLAUDE.md in the repo root and every directory containing a modified file. Pass paths to the Standards Checker agent.

**Build change context block** — gather intent/requirements from git metadata to include in all agent prompts:
```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
COMMITS=$(git log origin/main...HEAD --pretty=format:"- %s%n%b" --no-merges 2>/dev/null | head -50)

# Try to extract an issue number from the branch name (e.g. feat/GH-123-foo, fix/456-bar)
ISSUE_NUM=$(echo "$BRANCH" | grep -oE '[0-9]{2,}' | head -1)
ISSUE_CONTEXT=""
if [ -n "$ISSUE_NUM" ]; then
  ISSUE_CONTEXT=$(gh issue view "$ISSUE_NUM" --json number,title,body \
    -q '"Issue #\(.number): \(.title)\n\(.body)"' 2>/dev/null || "")
fi
```

Assemble a `CHANGE_CONTEXT` block:
```
Branch: <branch name>
Commits on this branch:
<commit messages>
<if issue found:>
Linked issue:
<issue title and body>
```

Prepend `CHANGE_CONTEXT` to every agent prompt. Agents use it to spot mismatches between intent and implementation.

**Initialize loop tracking:**
```
loop_count = 0
previous_findings_count = Infinity
```

---

## Step 2: Parallel Review — Launch 6 Agents

Launch all 6 agents simultaneously. Each agent runs its own git commands — do not pass diff text directly.

**Diff instruction to include in each agent prompt:**
- `HAS_UNCOMMITTED=true`: "Run `git diff` for unstaged changes, `git diff --cached` for staged changes, and `git diff origin/main...HEAD` for committed changes. Review all three."
- `HAS_UNCOMMITTED=false`: "Run `git diff origin/main...HEAD` to see the changes."

Prepend `CHANGE_CONTEXT` to every agent prompt before the diff instruction.

### Agent 1: Bug Hunter
```
subagent_type: code-reviewer-bug-hunter
description: "Review: bug hunting"
```
Prompt: `[CHANGE_CONTEXT]` `[diff instruction]` Focus only on introduced code (+ lines). Return findings or NO_ISSUES_FOUND.

### Agent 2: Standards Checker
```
subagent_type: code-reviewer-standards-checker
description: "Review: standards check"
```
Prompt: `[CHANGE_CONTEXT]` `[diff instruction]` Then read these CLAUDE.md files: `[discovered paths]`. Return findings or NO_ISSUES_FOUND.

### Agent 3: Context Reviewer
```
subagent_type: code-reviewer-context-reviewer
description: "Review: context analysis"
```
Prompt: `[CHANGE_CONTEXT]` `[diff instruction]` After reviewing the diff, read the full modified files to catch semantic issues. Return findings or NO_ISSUES_FOUND.

### Agent 4: Performance Reviewer
```
subagent_type: code-reviewer-performance-reviewer
description: "Review: performance"
```
Prompt: `[CHANGE_CONTEXT]` `[diff instruction]` Focus only on introduced code (+ lines). Use context7 to verify claims before reporting. Return findings or NO_ISSUES_FOUND.

### Agent 5: Test Coverage Reviewer
```
subagent_type: code-reviewer-test-coverage-reviewer
description: "Review: test coverage"
```
Prompt: `[CHANGE_CONTEXT]` `[diff instruction]` Flag missing tests on new business logic and test anti-patterns. Return findings or NO_ISSUES_FOUND.

### Agent 6: Quality Reviewer
```
subagent_type: code-reviewer-quality-reviewer
description: "Review: code quality"
```
Prompt: `[CHANGE_CONTEXT]` `[diff instruction]` Focus only on introduced code (+ lines). Flag naming, complexity, duplication, magic literals, and SRP violations. Return findings or NO_ISSUES_FOUND.

---

## Step 3: Validate Findings (Disprove-First)

If all 6 returned `NO_ISSUES_FOUND`, skip to Step 6.

For each finding with confidence >= 60, launch a validation agent in parallel (up to 8 concurrent):

```
subagent_type: code-reviewer-validator
description: "Validate: [brief issue description]"
model: haiku
```
Prompt:
```
CHANGE_CONTEXT:
[full CHANGE_CONTEXT block from Step 1]

Validate this finding by trying to DISPROVE it:
- file: [path]
- line: [line]
- category: [category]
- issue: [description]
- evidence: [evidence]

Your job is to disprove this finding. Read the file, find callers, check tests, check git blame, and read the CHANGE_CONTEXT above. Only VALIDATED if you cannot disprove it.

Return VALIDATED or DISMISSED with one-line reason.
If VALIDATED, also return category and fix_strategy (tdd or structural).
```

After validation:
- Keep only `VALIDATED` findings with confidence >= 80
- Discard everything else
- Record `findings_count` for circuit breaker

If no findings survived validation, skip to Step 6.

---

## Step 4: Auto-Fix

Route surviving validated findings by category and fix strategy:

### TDD fixes (`fix_strategy: tdd`)

Categories: `bug`, `security`, `logic`

For each finding:
1. Spawn `test-writer` agent — prompt includes the finding as context:
   ```
   Write a test that proves this bug exists:
   - file: [path]
   - line: [line]
   - issue: [description]
   - evidence: [evidence]

   The test should FAIL against the current code, proving the bug is real.
   Write exactly ONE test. Follow project test conventions.
   ```
2. Spawn `implementer` agent — minimal fix to make the test pass:
   ```
   Make this failing test pass with a minimal fix:
   - test file: [path to new test]
   - bug: [description]
   - file to fix: [path]

   Change only what's necessary. Do not refactor surrounding code.
   ```
3. Commit: `fix: [description of bug fixed]`

Run TDD fixes sequentially (test-writer → implementer → commit) per finding. Parallelize across findings only when files don't overlap.

### Structural fixes (`fix_strategy: structural`)

Categories: `standards`, `quality`, `performance`, `test-anti-pattern`

For each finding:
1. Spawn `refactorer` agent:
   ```
   Fix this code review finding:
   - file: [path]
   - line: [line]
   - issue: [description]
   - evidence: [evidence]

   Make the minimal structural change to resolve the issue.
   Do not change behaviour. Do not fix unrelated issues.
   ```
2. Commit: `tidy: [description of structural fix]`

Parallelize structural fixes when files don't overlap. Sequential when they share files.

### Commit discipline
- Bug/security/logic fixes → `fix:` commits (behavioral)
- Standards/quality/performance fixes → `tidy:` commits (structural)
- Never mix structural and behavioral in one commit

---

## Step 5: Re-Review Loop

After fixes are committed:

```
loop_count += 1
```

**Circuit breaker — stop if ANY of:**
- `findings_count == 0` after Step 3 → done, clean
- `loop_count >= 3` → not converging, report remaining to user
- `findings_count >= previous_findings_count` → not improving, report remaining to user

**If loop continues:**
```
previous_findings_count = findings_count
```
Go back to Step 2 with fresh agents and fresh context. Each loop gets clean agent instances — no carried-over state.

---

## Step 6: Final Report

```
## Code Review
[⚠ Includes uncommitted changes — only if HAS_UNCOMMITTED=true]

### Must Fix
[Validated bugs and security issues that could not be auto-fixed — file:line, what's wrong, concrete fix]

### Should Address
[Validated standards violations and test anti-patterns that could not be auto-fixed — file:line, quoted rule, fix]

### Auto-Fixed
[Summary of fixes applied during review]

### Positive Observations
[What's done well — reinforce good patterns]

Review loops: N (X findings → Y findings → ...)
Auto-fixed: N findings (N bugs via TDD, N structural)
Reviewed by: Bug Hunter, Standards Checker, Context Reviewer, Performance Reviewer, Test Coverage Reviewer, Quality Reviewer
Findings validated: X of Y passed validation
```

If clean after auto-fix:
```
## Code Review
[⚠ Includes uncommitted changes — only if HAS_UNCOMMITTED=true]

No issues remaining. Checked for bugs, security, performance, test coverage, code quality, and CLAUDE.md compliance.

Review loops: N (X findings → 0)
Auto-fixed: N findings (N bugs via TDD, N structural)
Reviewed by: Bug Hunter, Standards Checker, Context Reviewer, Performance Reviewer, Test Coverage Reviewer, Quality Reviewer
```

If loop hit circuit breaker:
```
## Code Review

Review loops: N (stopped — not converging)
Auto-fixed: N findings
Remaining findings:
- [file:line — description]
- [file:line — description]

Reviewed by: Bug Hunter, Standards Checker, Context Reviewer, Performance Reviewer, Test Coverage Reviewer, Quality Reviewer
```

---

## Communication Style

- Direct and specific — reference exact file:line
- Explain the "why" not just the "what"
- Concrete fix suggestions
- Pattern issues: suggest systemic fix rather than listing every instance
- Clear and actionable (developer has ADHD)

## Boundaries

- Don't review node_modules, dist, .git, .next
- Don't access .env files, but flag if they appear committed
- If unsure about a project pattern, dismiss rather than flag
- If not certain an issue is real, do not flag it
