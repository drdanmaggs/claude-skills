# `.github/claude-labels.yml`

One file per repo, **committed** (unlike `.tdd-phase`, which is gitignored — this one has to be visible to everyone working in the repo, and to CI).

Two readers, with very different appetites:

- **`hooks/label-gate.sh`** reads exactly one line — `enforce:` — with a single `grep`. No YAML parser, no network, well inside its 5s timeout.
- **`issue-labeller`** reads the whole thing.

## Schema

```yaml
version: 1

# Set false to switch the label gate off for this repo entirely — both the
# "issues need a label" rule and the "labels need approval" rule.
# Committed and reviewable, which is the point: opting out is a decision
# someone can see in the diff, not something that quietly happened.
enforce: true

# This repo's area vocabulary. DERIVED from labels the repo already uses
# (Mode B renames them), never invented. Zero areas is a valid config.
areas:
  - { name: "area:shopping-list", color: "1d76db", description: "Shopping list pipeline" }
  - { name: "area:testing",       color: "1d76db", description: "Test suites and infrastructure" }

# Labels owned by other systems. issue-labeller never creates, deletes or
# assigns these. Extends (does not replace) the reserved list in canon.yml.
reserved:
  - automated-audit     # written by this repo's CI

# Audit trail: what Mode D consolidated away, and into what. Kept so the next
# person to see an old link or a stale bookmark can work out where it went.
retired:
  - { name: refactor,      merged_into: technical-debt, issues: 37 }
  - { name: high-priority, merged_into: null, reason: "no priority axis", issues: 15 }
```

## Fields

| Field | Required | Notes |
|---|---|---|
| `version` | yes | `1`. Bump only on a breaking schema change. |
| `enforce` | yes | `true`/`false`. The hook greps `^enforce:[[:space:]]*false`. Anything else, including a missing file, means enforced. |
| `areas` | no | Repo's `area:*` vocabulary. Absent or empty = types only. |
| `reserved` | no | Appended to `canon.yml`'s reserved list. |
| `retired` | no | Audit trail. Never read by tooling — read by people. |

## Default when the file is absent

**Enforced.** The gate is active in every repo out of the box.

This differs from `tdd-gate.sh`, which is invisible without a `.tdd-phase` file, and the difference is deliberate: TDD is a mode you enter, but "an issue has a label" is an invariant. The repos with the worst labelling — `ci-power` at 100% unlabelled, `dev-box-janitor` at 88%, `ci-runners` at 85% — are precisely the ones that would never have added an opt-in file. An opt-in gate here would be an instruction you can silently skip, which is the failure this whole thing exists to prevent.

## Escape hatches

1. **Per call** — `CLAUDE_LABELS_SKIP=1 gh issue create ...`. One-shot and visible in the transcript. Cannot be set and forgotten.
2. **Per repo** — `enforce: false` here. Committed and reviewable.

## Lookup

The hook walks up from the session `cwd` looking for `.github/claude-labels.yml` and stops at the first hit. In a worktree layout each checkout carries its own copy, so they can't disagree by accident.
