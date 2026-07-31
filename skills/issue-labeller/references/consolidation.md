# Consolidation heuristics

How to tell a redundant label from a useful one, and what to do about it.

## How taxonomies rot

Three signatures, all observable from `gh label list --json name,color,description`:

1. **Grey and undescribed** — colour `#ededed`, empty description. That's bare `gh label create <name>` with no other arguments: someone needed a label in the moment and never came back. Eleven of family-meal-planner-v3's 28 labels look like this.
2. **Parallel systems** — the same axis expressed twice because the second author didn't see the first. productivity-coach-mvp carries `high-priority`/`medium-priority` (grey, undescribed) *alongside* `priority: critical`/`priority: low` (coloured, described): two waves, neither retired.
3. **Case and spelling drift** — `Priority: Low` next to everything-else-lowercase, `refactor` vs `refactoring`, `tech-debt` vs `technical-debt`. The last one is worth noticing because a query written against the wrong spelling silently returns nothing forever.

## Clustering rules

**MERGE** when two labels would never make you do something different. `refactor` and `code-quality` both mean "this works but I don't like it" — that's `technical-debt`. `ui` and `ux` differ meaningfully in a design team and not at all in a solo repo; merge unless the repo has separate owners for them.

**RENAME-TO-AREA** when the label names a *part of the system* rather than a *kind of work*: `security`, `performance`, `shopping-list`, `typescript`. These become `area:*`. The prefix isn't cosmetic — it makes `area:*` queryable as a group and guarantees a future type label can't collide with one.

**RETIRE-UNUSED** at zero issues. A label nobody has ever applied is a label nobody will apply.

**RETIRE-PRIORITY** always, into its own bucket, with **no replacement offered**. See below.

**RESERVED-KEEP** for anything in `canon.yml`'s reserved list or the repo's own `reserved:`. Routing labels (`workflow:*`), bot labels (`dependencies`), board state (`blocked`, `ready`), and `epic`.

**A release gate is not a label.** `pre-launch`, `post-mvp`, `deferred`, `quarterly-review` answer "when", not "what". Offer converting these to a **GitHub milestone** — a milestone has an owner and a due date, and it closes. Never delete one outright: `pre-launch` carries 41 issues in fmp, and deleting it destroys the only record of which those were.

## Priority: retire, never replace

The canon has no priority axis, and Mode D must not smuggle one back in by "consolidating" four priority labels into one clean scheme.

The evidence is that these labels don't survive contact with time. productivity-coach-mvp grew **three** parallel priority systems; the newer, better-designed one (`priority: critical`, `priority: low` — coloured, described) has **fewer** uses than the older grey one it was meant to replace. A label saying "I care about this more" decays the moment its author moves on, and nothing forces a re-read. Milestones and the project board carry ordering with an owner and a date attached.

So: retire them into their own bucket, print every affected issue number, and offer nothing in their place.

## Order of operations

Renaming preserves issue assignments. Deleting does not. Never invert these:

```bash
# 1. carry the issues across
gh api --method PATCH /repos/{owner}/{repo}/labels/{old} -f new_name={new}

# 2. prove the old label is empty
gh issue list --repo {owner}/{repo} --state all --label {old} --json number -q 'length'   # must print 0

# 3. only now
gh label delete {old} --repo {owner}/{repo} --yes
```

When two labels merge into one that *already exists*, a rename would collide. Re-label the issues instead, then delete:

```bash
# e.g. {old}=code-quality, {new}=technical-debt
for n in $(gh issue list --repo {owner}/{repo} --state all --label {old} --json number -q '.[].number'); do
  gh issue edit "$n" --repo {owner}/{repo} --add-label {new} --remove-label {old}
done
```

## Presenting

Every retirement shows its full affected issue-number list. Not a count — the numbers. A count is a thing the user can nod at; the numbers are a thing they can check.

Approval is **per bucket**, so renames can proceed while deletions are declined.

---

## Worked mapping — `Maggnetic/productivity-coach-mvp` (38 → 21)

Counts are all-state, taken 2026-07-31. **Re-run `scripts/label-usage.sh` before acting** — these are for shape, not for execution.

| Current | Uses | Action |
|---|---|---|
| `bug` · `enhancement` · `documentation` | 108 · 178 · 10 | keep |
| `technical-debt` | 104 | keep; set colour `5319e7` + description |
| `refactor` | 37 | **merge** → `technical-debt` |
| `code-quality` | 11 | **merge** → `technical-debt` |
| `chore` · `ci-failure` · `flaky-test` | 11 · 76 · 16 | keep |
| `testing` | 23 | rename → `area:testing` |
| `ui` · `ux` | 32 · 15 | **merge** `ux`→`ui`, then rename → `area:ui` |
| `performance` · `security` · `accessibility` | 12 · 3 · 1 | rename → `area:performance` · `area:security` · `area:a11y` |
| `typescript` · `logging` | 6 · 4 | rename → `area:types` · `area:observability` |
| `agent` · `recurring-tasks` | 15 · 77 | rename → `area:agent` · `area:recurring-tasks` |
| `high-priority` · `medium-priority` · `priority: critical` · `priority: low` | 15 · 4 · 2 · 1 | **RETIRE — no replacement** (~22 issues) |
| `post-mvp` | 12 | retire → offer milestone |
| `quarterly-review` | 1 | retire |
| `good first issue` · `help wanted` · `invalid` · `wontfix` | ~2 · 0 · 0 · 0 | retire unused defaults |
| `epic` · `needs-triage` · `ready` · `blocked` · `consider-closing` · `duplicate` · `dependencies` · `javascript` | — | **reserved — keep** |

## Worked mapping — `Maggnetic/family-meal-planner-v3` (28 → 19)

| Current | Uses | Action |
|---|---|---|
| `bug` · `enhancement` · `documentation` · `question` | 139 · 213 · 9 · 3 | keep |
| `technical-debt` | 181 | keep; set colour + description |
| `refactoring` · `architecture` | 11 · 9 | **merge** → `technical-debt` |
| `flaky-test` · `ci-failure` | 87 · 34 | keep |
| `testing` | 103 | rename → `area:testing` |
| `typescript` · `infrastructure` | 31 · 24 | rename → `area:types` · `area:ci` |
| `observability` · `performance` · `security` | 24 · 16 · 16 | rename → `area:*` (same stem) |
| `shopping-list` · `meal-planning` | 18 · 11 | rename → `area:shopping-list` · `area:meal-planning` |
| `Priority: Low` | 2 | **RETIRE — no replacement** |
| `user-feedback` | 8 | retire — provenance belongs in the body, not a label |
| `polish` | 1 | merge → `enhancement`, then retire |
| `pre-launch` · `deferred` | 41 · 7 | retire → **offer milestone**, never a bare delete |
| `epic` · `automated-audit` · `dependencies` · `javascript` · `github_actions` | — | **reserved — keep** |
