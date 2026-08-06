---
name: code-reviewer
description:
  Use this skill to review code. It supports both local changes (staged or working tree) and remote Pull Requests (by ID or URL). It focuses on correctness, maintainability, and adherence to project standards. Uses parallel review agents with a validation pass to deliver high-signal findings only. Runs all six agents by default; callers can request an incremental round scoped to a since-sha. Emits a postable artefact recording which agents ran and why any were skipped.
allowed-tools: Read Grep Glob Task Bash(git diff:*) Bash(git log:*) Bash(git status:*) Bash(git rev-parse:*) Bash(git merge-base:*) Bash(gh pr checkout:*) Bash(gh pr view:*) Bash(gh api:*) Bash(gh issue view:*) Bash(git add:*) Bash(git commit:*)
---

# Code Reviewer

Orchestrate a multi-agent code review with auto-fix. Focus on what automated tools (lint, types, build) can't catch. HIGH SIGNAL ONLY — false positives erode trust.

## Invocation Modes

Two modes. **Default to `full` whenever the caller does not say otherwise** — a
missing mode is not an invitation to guess something cheaper.

| Mode | Scope | Agents |
|---|---|---|
| `full` | `git diff origin/main...HEAD` | all 6 |
| `incremental <since-sha>` | `git diff <since-sha>...HEAD` | selected by the tier rules below |

`full` is for the first review of a branch and for any round where escalation
fires. `incremental` is for later rounds, once an earlier round has already
covered everything up to `<since-sha>`.

Whichever mode runs, the uncommitted-changes handling in Step 1 still applies on
top of it.

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

Let `BASE_DIFF` be `git diff origin/main...HEAD` in `full` mode, or
`git diff <since-sha>...HEAD` in `incremental` mode.

- **Non-empty output** → `HAS_UNCOMMITTED=true`. Agents must run all three: `git diff` (unstaged) + `git diff --cached` (staged) + `BASE_DIFF` (committed).
- **Empty output** → `HAS_UNCOMMITTED=false`. Agents run `BASE_DIFF` only.

**Quick bail** — if ALL changed files match these patterns, report "No code to review" and stop:
- `*.md`, `*.mdx`, `*.json` (unless package.json deps changed), `*.lock`, `*.lockb`, `*.yml`, `*.yaml`

Bailing is a legitimate outcome, but it is never silent: still emit the artefact
(Step 7) recording the round as skipped **and why**. A round that produced no
review and left no trace is indistinguishable from a round that never ran, which
is the failure this whole design exists to prevent.

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

## Step 2: Select Agents

**`full` mode → all 6. Skip the rest of this step.**

**`incremental` mode** — measure the delta, counting **non-test source files** only
(exclude `*.test.*`, `*.spec.*`, `*_test.*`, `__tests__/`, `tests/`, and the quick-bail
patterns above):

| Tier | Agents | Runs when |
|---|---|---|
| A | Bug Hunter, Standards Checker | always |
| B | Context Reviewer, Test Coverage Reviewer | any non-test source file in the delta |
| C | Performance Reviewer, Quality Reviewer | delta ≥ 50 changed lines **or** ≥ 5 files |

**Escalate to `full` — all 6, over `origin/main...HEAD` — if ANY of:**
- the previous round produced a validated finding with category `bug` or `security`
- the delta touches ≥ 15 files
- no `<since-sha>` could be established, or it is not an ancestor of `HEAD`

Escalation is deliberately asymmetric: cheap to trigger, and it always widens the
review rather than narrowing it. When in doubt about which tier applies, run the
larger set.

**These are rules, not judgment, on purpose.** A rule can be written into the
artefact and checked afterwards. This stage was removed from `/ship` once because
it silently drifted from six agents to three to two to never running, and nothing
downstream could tell. A reduced round is fine — an *unexplained* one is not. Every
agent not run must appear in the artefact by name with the rule that excluded it.

## Step 2b: Parallel Review — Launch the Selected Agents

Launch the selected agents simultaneously. Each agent runs its own git commands — do not pass diff text directly.

**Diff instruction to include in each agent prompt:**
- `HAS_UNCOMMITTED=true`: "Run `git diff` for unstaged changes, `git diff --cached` for staged changes, and `BASE_DIFF` for committed changes. Review all three."
- `HAS_UNCOMMITTED=false`: "Run `BASE_DIFF` to see the changes."

(Substitute the literal command `BASE_DIFF` resolves to for this round.)

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

If every agent returned `NO_ISSUES_FOUND`, skip to Step 6.

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

**Internal loops re-review incrementally.** Round 1 of an invocation is whatever
mode the caller asked for; rounds 2+ run `incremental` since the sha reviewed at
the start of the previous round, under the same Step 2 tier and escalation rules.
So "full first, intelligent after" holds within a single invocation as well as
across `pr-quality` rounds — and the escalation trigger means a round that found a
bug widens the next one back to all 6 rather than narrowing it.

---

## Step 6: Emit the Artefact

**One output, always.** It is both the report shown to the user and the body a
caller posts to the PR. There is no separate short form — a divergent "summary"
version is how the detail that makes degradation visible gets lost.

It is emitted to the conversation **and** written to `.local-review.md` — see
[Write it to `.local-review.md`](#write-it-to-local-reviewmd) below. Both, every
time. The file is what callers post; the conversation copy is what you read.

```markdown
<!-- local-review sha=<full 40-char HEAD sha> round=<n> agents=<ran>/6 -->
## Local review — round <n>

**Scope:** `<base>...<head>` (<full branch diff | delta since round n-1>) · <N> files, <N> lines
**Agents (<ran>/6):** <names of agents that ran>
**Not run:** <names> — <the rule that excluded them, e.g. "delta below Tier C (41 lines, 3 files)">

[⚠ Includes uncommitted changes — only if HAS_UNCOMMITTED=true]

### Must fix
[Validated bugs and security issues that could not be auto-fixed — file:line, what's wrong, concrete fix]

### Should address
[Validated standards violations and test anti-patterns that could not be auto-fixed — file:line, quoted rule, fix]

### Auto-fixed
[Fixes applied during this review — N bugs via TDD, N structural]

### Positive observations
[What's done well — reinforce good patterns]

Findings validated: X of Y · Review loops: N (X findings → Y → …)
```

Rules for the marker line — the CI assertion parses it, so these are load-bearing:

- **`sha` must be the full 40-character HEAD sha at review time**, not short, not a branch name. The assertion keys on it for the same reason `assert-review-posted.sh` keys on a `SINCE` stamp: without it one stale review satisfies every later push, and the guard passes forever after a single success — worse than no guard, because it still looks like one.
- **`agents=<ran>/6` must be the real count.** If it disagrees with the `Agents:` line, the artefact is lying and the whole mechanism is void.
- **Omit no section by silence.** `Not run: none` when all 6 ran. `Auto-fixed: none` when nothing was fixed.

Section variants:

- **Clean** — keep every heading, write "No issues remaining." under Must fix. Do not collapse the artefact.
- **Circuit breaker hit** — add `**Stopped:** not converging after N loops` under the Agents lines, and list remaining findings under Must fix.
- **Quick bail** (docs/config-only) — emit the header, marker, and `**Skipped:** no reviewable code in scope — all changed files are docs/config`. The marker still carries the real sha, because the round genuinely covered that sha.

### Write it to `.local-review.md`

Write the artefact — the whole block, starting at the `<!-- local-review sha=… -->`
marker — to **`.local-review.md`** at the repo root, with the Write tool,
overwriting whatever was there. Then ensure it is gitignored:

```bash
grep -qxF '.local-review.md' .gitignore 2>/dev/null || printf '%s\n' '.local-review.md' >> .gitignore
```

**Byte-identical to what you emitted.** Not a summary of it, not a re-rendering of
it, not "the same thing but tidier for the file". One artefact with two
destinations. If the two ever differ, the one the merge button sees is the file,
and you have just made the conversation copy a lie.

**This skill is the writer, not its callers.** `code-reviewer` is invoked by
`/ship`, by `pr-quality`, and directly by the user. Writing at emission means all
three get it for free and none of them can forget; writing at receipt means three
implementations that drift.

**Why a file at all.** The artefact is the most compaction-fragile object in the
chain — `/ship` used to carry it through two more stages in conversation before
posting it, and this skill already says a mangled marker reads as no review at
all. A file survives `/compact`, `/clear`, and a cold restart; a held block does
not.

Note the asymmetry with `.tdd-phase` and `.tdd-session.md`, which `/tdd` deletes at
Completion: **`.local-review.md` is not torn down here.** The caller still has to
post it, and that may happen after a `/clear`. It is overwritten by the next
review, which is the only lifecycle it needs. Callers guard against a stale one by
checking the `sha=` marker, never by assuming freshness.

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
