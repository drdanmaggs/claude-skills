# claude-skills

A Claude Code plugin: 22 general-purpose skills and 15 supporting agents for test-driven
development, code review, shipping, and project hygiene.

These previously lived inside [rocket-fuel](https://github.com/drdanmaggs/rocket-fuel), a
multi-agent orchestrator. They don't belong there — none of them know the orchestrator
exists, and bundling them meant a one-line fix to `/ship` required a version bump on an
unrelated Go project. See ADR-009 in that repo for the reasoning.

## Install

```bash
claude plugin marketplace add drdanmaggs/claude-skills
claude plugin install claude-skills
```

Invoke as `/claude-skills:<name>` — e.g. `/claude-skills:tdd`. Most skills also
auto-trigger on relevant phrasing.

## Skills

### Development loop

| Skill | What it does |
|---|---|
| `tdd` | RED/GREEN/REFACTOR with context-isolated subagents per phase |
| `ship` | End-to-end pre-PR: commit, lint, review, fix, draft PR |
| `create-pr` | PRs with titles that pass conventional-commit CI validation |
| `pr-quality` | Autonomous loop — processes review feedback and CI until clean |
| `resolve-conflict` | Rebases and resolves conflicts, stopping only when genuinely ambiguous |
| `git-workflow` | Commit, branch and PR conventions |

### Review

| Skill | What it does |
|---|---|
| `code-reviewer` | Parallel review agents plus a validation pass; high-signal findings only |

Backed by seven agents: `code-reviewer-bug-hunter`, `-context-reviewer`,
`-performance-reviewer`, `-quality-reviewer`, `-standards-checker`,
`-test-coverage-reviewer`, and `-validator`, which tries to disprove findings before they
are reported.

### Testing

| Skill | What it does |
|---|---|
| `test-fixer` | Diagnoses and fixes failures across Playwright, Vitest, Jest, RTL |
| `skip-failed-test` | Decides whether a failure is yours or flaky; skips with a tracked issue |
| `critical-path-testing` | Risk-driven — test critical paths first, coverage is an output |
| `test-coverage-retrofit` | Coverage-driven parallel test writing for legacy code |
| `supabase-rls-testing` | Vitest integration tests for Row Level Security policies |

### Project hygiene

| Skill | What it does |
|---|---|
| `issue-scope` | Turns vague features into scoped plans with test decomposition |
| `issue-triage` | Evaluates a backlog against the real codebase; drops what's stale |
| `github-issue-relationships` | Blocked-by/blocking links and epic hierarchies |
| `write-concise-docs` | Rewrites verbose docs into scannable, token-efficient form |
| `skill-creator` | Guide for writing and updating skills |

### Stack-specific

| Skill | What it does |
|---|---|
| `frontend-design` | Distinctive production-grade UI that avoids generic AI aesthetics |
| `vercel-react-best-practices` | React/Next.js performance patterns from Vercel Engineering |
| `react-email` | HTML email templates as React components |
| `resend` | Sending, receiving, audiences, broadcasts |
| `email-best-practices` | Deliverability, SPF/DKIM/DMARC, compliance |

## Deliberately not included

Some skills are better taken from their vendor than vendored here. Install these with the
[Skills CLI](https://skills.sh/) instead — they are first-party and stay current on their
own:

```bash
npx skills add vercel-labs/skills@find-skills          # discovers and installs skills
npx skills add langfuse/skills@langfuse                # LLM observability
npx skills add stripe/ai@stripe-best-practices         # Stripe integration guidance
```

This plugin shipped its own `find-skills` and `langfuse` until they were removed in favour
of the upstream versions, which are maintained by the tools' own authors. A second copy
here would shadow whichever one you installed and then rot.

## Hooks

`hooks/tdd-gate.sh` is a `PreToolUse` gate that enforces TDD phase discipline. It reads a
`.tdd-phase` file at the repo root and blocks edits that violate the current phase:

| Phase | Tests | Source |
|---|---|---|
| RED | allow | deny |
| GREEN | deny | allow |
| REFACTOR | deny | allow |

It is completely invisible when no `.tdd-phase` file exists, so it never affects non-TDD
work. Run its 13-case offline test matrix with:

```bash
bash hooks/tdd-gate.test.sh
```

## Rules do not belong here

`rules/` is not a plugin primitive. A `rules/` directory in a plugin is copied into the
install cache and never loaded — nothing reads it. Rocket Fuel shipped eight rule files
that way for four months with no effect whatsoever.

Rules that actually load live in `~/.claude/rules/`, referenced from `~/.claude/CLAUDE.md`.
Put them there.

The failure mode is quiet: of the five files that existed in both places, four were
byte-identical and `testing.md` had drifted, with the *better* version — a section on tests
owning their own data rather than querying for pre-existing records — sitting in the copy
nothing read. It was ported across before the plugin copy was deleted.

## Relationship to rocket-fuel

`rocket-fuel` keeps only what depends on it: the `board-setup` and `worktree-reset` skills
and the `integrator` and `worker` agents. Its worker agents dispatch to skills in *this*
plugin, so if you run rocket-fuel you want both installed.
