# Shared Review Contract

Subagents: read this before returning findings. Apply these filters ruthlessly.

## High Signal Filter

**DO flag (confidence 80+):**
- Code will definitely produce wrong results regardless of inputs (clear logic errors)
- Clear CLAUDE.md violation — quote the exact rule being broken
- Security vulnerability in introduced code (exposed secrets, SQL injection, XSS, unsafe input)
- Will break at runtime (missing await on critical path, null access crash, broken import)

**DO NOT flag (automatic dismiss):**
- Code style or quality concerns — Prettier and ESLint handle these
- Potential issues that depend on specific inputs or state
- Subjective suggestions or improvements
- Pre-existing issues not introduced by this change
- Issues a linter or type checker will catch
- Issues silenced by lint-ignore comments with justification
- "Could be more elegant" — if it works and is readable, it's fine
- Missing tests for trivial changes (UI tweaks, copy, config)
- Documentation files — don't security review markdown

## Universal False Positive Patterns

Never flag these regardless of domain:

- **Pre-existing code** — If the issue existed before this change, it's not a finding
- **Pedantic nitpicks** — Would a senior engineer actually flag this in a real review? If no, skip
- **Linter territory** — Import ordering, formatting, naming conventions, unused vars
- **Lint-ignore with reason** — Code explicitly silenced with a justification comment is intentional
- **General quality concerns** — "Add error boundary", "add logging" — unless CLAUDE.md requires it
- **Enterprise patterns for simple code** — Abstract factories, DI containers, repository patterns
- **YAGNI** — Premature optimisation, splitting files under 200 lines, "you might need this later"
- **Environment variables and CLI flags** — Trusted by convention
- **Design decisions following existing patterns** — If the project already does it this way, don't flag it

## Confidence Scoring

Rate each finding 0-100:
- **90-100**: Certain — will break at runtime, clear security hole, quotable rule violation
- **80-89**: High confidence — very likely a real issue, minimal ambiguity
- **60-79**: Medium — plausible but needs validation (will be verified by validation agent)
- **Below 60**: Do not report — too speculative

## Output Format

Return findings as a structured list. Each finding must include:

```
- file: path/to/file.ts
  line: 42
  issue: Brief description of what's wrong
  confidence: 85
  category: bug | security | standards | logic | performance
  evidence: The specific code or rule that proves this is real
```

If no issues found, return: `NO_ISSUES_FOUND`
