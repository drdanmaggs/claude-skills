# Issue Evaluation Criteria

Subagents: read this file before evaluating. Apply these filters ruthlessly.

## Core Principle

PR suggestions evaluate code you're actively touching — low bar to act. Backlog issues evaluate code you're NOT touching — the bar for keeping is **higher**. Every open issue is cognitive tax. The issue must justify its existence.

**The test: "Does this issue describe a real, verified problem with a predictable fix?"**

## Verification Steps

Before scoring, the subagent MUST verify:

1. **File existence** — Do referenced files still exist? (Glob)
2. **Problem existence** — Is the described problem still in the code? (Read the file)
3. **Already fixed** — Was this addressed by later commits? (git log on referenced files)
4. **Handled elsewhere** — Is the concern handled by middleware, framework, parent component, or upstream caller? (Grep/search)

If any verification fails → auto-CLOSE with specific reason.

## YAGNI for Backlog

| Question | KEEP if... | CLOSE if... |
|----------|-----------|-------------|
| Is the problem real? | Verified in current code | Speculative, already fixed, or handled elsewhere |
| Is the fix specific? | Concrete change described | Vague ("consider refactoring", "add error handling") |
| Is the cost predictable? | < 30 min, bounded scope | Unclear scope, cascading changes, "comprehensive" anything |
| Is there evidence of impact? | Bug reports, errors in logs, crash risk | "Best practice" with no evidence of actual problems |
| Does it conflict with architecture? | Aligns with CLAUDE.md and patterns | Contradicts existing decisions or patterns |
| Is it actionable NOW? | Could be picked up by any developer | Requires decisions, research, or design work first |

**3+ CLOSE answers → CLOSE. The issue isn't earning its place.**

## Confidence Calibration

| Score | Meaning | Example |
|-------|---------|---------|
| 90-100 | Certain — clear evidence | File deleted, problem already fixed in commit abc123 |
| 80-89 | High — strong evidence | Problem exists but framework handles it via middleware |
| 50-79 | Medium — needs deeper reasoning | Problem might exist but unclear if the fix is right |
| <50 | Low — speculative | Can't determine if problem is real |

### Threshold Behaviour

- **KEEP ≥80%:** Issue verified, problem real, fix predictable
- **50-79%:** Use sequential thinking (`mcp__sequential-thinking__sequentialthinking`) to reason deeper. Investigate execution paths, framework guarantees, actual usage. Arrive at KEEP or CLOSE — don't punt.
- **CLOSE ≥80%:** Clear reason to close (already fixed, speculative, YAGNI)
- **<50% either way:** Flag as UNCERTAIN for orchestrator

## Auto-CLOSE Patterns

These are almost always closeable without deep investigation:

| Pattern | Close reason |
|---------|-------------|
| "Consider adding..." / "Might benefit from..." | Speculative — no evidence of problem |
| "Add comprehensive error handling" | Unpredictable scope |
| "Refactor X module" (no specific problem) | Solution without a problem |
| "Performance optimisation" (no evidence) | Premature optimisation |
| "Add tests for X" (untouched code) | Not actionable in isolation |
| Referenced file no longer exists | Stale — code has moved on |
| Problem fixed in subsequent PR | Already resolved |
| "Project-wide concern" | Too broad for a single issue |

## Auto-KEEP Patterns

These almost always earn their place:

| Pattern | Keep reason |
|---------|------------|
| Security vulnerability with specific location | Real risk, specific fix |
| Bug with reproduction path | Verified defect |
| Missing null/error check on user-facing path | Crash risk |
| Documented tech debt blocking a planned feature | Clear dependency |
| Type safety issue with specific `any` usage | Matches project standards (CLAUDE.md) |

## Output Format

Return evaluation as:

```
issue: #{number}
title: {title}
verdict: KEEP | CLOSE
confidence: {0-100}
reasoning: {1-2 sentences}
close_reason: {if CLOSE — specific category from auto-close patterns}
referenced_files: [{list of files checked}]
```
