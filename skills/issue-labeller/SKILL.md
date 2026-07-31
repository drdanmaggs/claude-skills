---
name: issue-labeller
description: >
  Apply and maintain a consistent GitHub issue label taxonomy. Assigns a required type
  label and optional area: labels to issues being created or already open, initialises a
  repo's label set from the canon, retrofits labels onto an unlabelled backlog, and
  proposes consolidation of redundant labels for approval. Never assigns priority.
  Use when creating a GitHub issue, when issues are unlabelled, or when the label list
  has grown redundant. Triggers on: label this issue, add labels, unlabelled issues,
  label taxonomy, too many labels, consolidate labels, tidy labels, set up labels,
  retrofit labels, what label should this have.
allowed-tools: Read Grep Glob Task Bash(gh issue:*) Bash(gh label:*) Bash(gh api:*) Bash(gh repo view:*) Bash(git remote:*)
---

# Issue Labeller

Every issue carries **exactly one type label** and **zero to two `area:` labels**. Nothing else. The taxonomy grows only with the user's approval.

**There is no priority axis.** Never assign, create, or propose one — not even when retiring the ones a repo already has. See `no_priority` in [canon.yml](references/canon.yml) for why.

Read [references/canon.yml](references/canon.yml) before doing anything. It is the source of truth for types, the `area:` shape, and the reserved names other systems own.

**Enforced by a hook.** `hooks/label-gate.sh` denies `gh issue create` without a label, and denies label creation without a fresh approval token. You cannot work around it by being careful — write the labels.

---

## Modes

| Mode | When | Approval |
|---|---|---|
| **A · label** | Filing an issue now, or fixing one issue | None — additive and reversible |
| **B · init** | Repo has no canon labels, or names are off-canon | Before any write |
| **C · retrofit** | A backlog of unlabelled issues | Before the batch executes |
| **D · consolidate** | Label list has grown redundant | Per bucket |

Modes B, C and D accept `--dry-run`: print every `gh` command that would run, then stop.

---

## Mode A — label one issue

1. Read `canon.yml`. Read the repo's `.github/claude-labels.yml` if present for its declared areas; otherwise `gh label list --limit 200 --json name` and use existing `area:*` labels.
2. Pick **exactly one** type. When it's genuinely ambiguous, ask — don't default to `enhancement`.
3. Pick 0–2 areas. Zero is a fine answer; a wrong area is worse than none.
4. Apply:

```bash
gh issue create --title "..." --body-file - --label technical-debt --label area:ci <<'EOF'
...
EOF

gh issue edit 42 --add-label bug --add-label area:testing
```

**Choosing the type** — the distinctions that actually decide it:

- `bug` vs `technical-debt` — does it produce wrong behaviour a user could hit? Bug. Does it work correctly but cost you to live with? Debt.
- `technical-debt` vs `chore` — debt is design cost you chose to carry; a chore is mechanical (bump a dep, rename a file, delete dead config).
- `enhancement` — a *new user-visible capability*, not "anything that isn't a bug". This is the label most likely to be wrong; it is a catch-all in both large repos.
- `test-gap` vs `flaky-test` — missing coverage vs a test that fails non-deterministically.
- `ci-failure` — CI broken on the default branch. Not "a test failed in my PR".

---

## Mode B — initialise a repo's taxonomy

1. `gh label list --limit 200 --json name,color,description`
2. Run `scripts/label-usage.sh <owner/repo>` — a rename decision needs to know whether the label carries 0 issues or 100.
3. Diff against the canon and sort into three buckets:
   - **CREATE** — canon types the repo lacks
   - **RENAME** — existing labels that map onto a canon name or an `area:` form. Renaming **preserves every issue assignment**, so this is near-free
   - **LEAVE** — reserved names (see `canon.yml`), plus anything you can't confidently map
4. Present all three with counts. **Wait for approval.**
5. On approval, write the token so the hook lets label writes through, then execute:

```bash
: > "${TMPDIR:-/tmp}/.claude-label-canon-approved"      # 30-minute window
skills/issue-labeller/scripts/sync-labels.sh create <owner/repo>
skills/issue-labeller/scripts/sync-labels.sh rename <owner/repo> security area:security
```

6. Write `.github/claude-labels.yml` in the target repo — schema in [references/repo-config.md](references/repo-config.md). Commit it; the hook reads its `enforce:` line.

**Mode B never deletes.** `sync-labels.sh` refuses. Deletion is Mode D.

---

## Mode C — retrofit an existing backlog

**Run [issue-triage](../issue-triage/SKILL.md) first if the backlog looks noisy.** It closes 60–70% of issues on a typical pass; labelling first spends two-thirds of this fan-out on issues about to be closed. If triage has already run, take its KEEP list and pass those numbers straight in.

### Stage 1 — fetch and partition

```bash
gh issue list --state open --limit 300 --json number,title,body,labels
```

Partition into:
- **(a) zero labels** — the main target
- **(b) `enhancement`-only** — the catch-all bucket; re-type these, which usually means *removing* `enhancement`
- **(c) already carries a canon type** — skip, unless the user asked for a full audit

Report: `Found {N} open. {a} unlabelled, {b} enhancement-only, {c} already typed.`

### Stage 2 — fan out

**10 issues per subagent, up to 25 concurrent** — 250 issues in one wave. (`issue-triage` uses one issue per agent because each agent greps the codebase deeply; here the per-issue work is "read title and body, pick from a nine-item list", so batching is free.)

```
subagent_type: general-purpose
model: sonnet
description: "Label: #{first}-#{last}"
tools: Read, Grep, Glob          # no Bash, no gh — a stray agent cannot mutate anything
```

Prompt — embed the canon inline rather than pointing at a path, so the agent can't read a stale or missing file:

```
Assign GitHub issue labels. Return data only, no prose.

TYPES — choose EXACTLY ONE per issue:
  bug             Something isn't working (wrong behaviour a user could hit)
  enhancement     New user-visible capability (NOT a catch-all)
  documentation   Docs improvements or additions
  question        Further information is requested
  technical-debt  Works correctly but costs us to live with
  chore           Mechanical upkeep — deps, config, renames
  test-gap        Missing or inadequate test coverage
  flaky-test      Test fails non-deterministically
  ci-failure      CI broken on the default branch

AREAS — choose 0 to 2, ONLY from this repo's declared list:
{area list}

There is NO priority axis. Never output a priority, severity, or
critical/high/medium/low label, whatever the issue body says.

If the issue references files, you may Glob/Read them to decide — but do
not go deeper than needed to pick a type.

Issues:
{10 issues: number, title, body truncated to 1500 chars, current labels}

Return exactly one line per issue, no other output:
#<number> | type=<type> | areas=<comma-separated or -> | conf=<0-100> | why=<max 12 words>
```

### Stage 3 — present

Split on confidence:
- **conf ≥ 80** → auto-batch
- **conf < 80** → per-issue review list, shown with the agent's reasoning

Present additions and **removals in separate sections** — a removal is the part worth reading twice:

```
ADD ({n} issues, conf>=80):
  #1874  ci-failure  area:ci        — false green on undrafted PR
  ...

RE-TYPE (removes `enhancement`) ({m}):
  #1872  enhancement -> technical-debt  + area:data

NEEDS REVIEW (conf<80) ({k}):
  #1565  ci-failure? technical-debt?  (62) — destroys local test stack volumes
```

**Wait for approval.**

### Stage 4 — execute

Chunks of 20, then re-report:

```bash
gh issue edit 1874 --add-label ci-failure --add-label area:ci
gh issue edit 1872 --add-label technical-debt --remove-label enhancement
```

Only ever remove `enhancement`, and only when re-typing. Never remove a reserved label.

---

## Mode D — consolidate a redundant taxonomy

Read [references/consolidation.md](references/consolidation.md) — it holds the clustering heuristics and the two worked mappings.

1. `scripts/label-usage.sh <owner/repo>` for real counts.
2. Cluster into five buckets:

| Bucket | Action |
|---|---|
| **MERGE** | Two labels mean the same thing → rename one onto the other |
| **RENAME-TO-AREA** | A topic label → `area:*` |
| **RETIRE-UNUSED** | Defined, zero issues → delete |
| **RETIRE-PRIORITY** | Its own bucket. **No replacement offered.** |
| **RESERVED-KEEP** | Owned elsewhere — never touched |

3. Present each bucket with per-label issue counts, the exact commands, and — for every retirement — **the full list of affected issue numbers**. A retirement the user can't see the cost of is a silent one.
4. **Approval is per bucket.** The user can take the renames and decline the deletions.
5. Execute in this order, and not out of it:

```bash
# 1. carry the issues across (rename preserves assignments; delete does not)
scripts/sync-labels.sh rename <owner/repo> refactor technical-debt

# 2. verify nothing is left on the label
gh issue list --repo <owner/repo> --state all --label <old> --json number -q 'length'   # must be 0

# 3. only then
gh label delete <old> --repo <owner/repo> --yes
```

**When a label is really a release gate** — `pre-launch`, `post-mvp`, `deferred` — offer converting it to a **GitHub milestone** rather than a bare delete. A milestone has an owner and a date; a colour on an issue has neither.

---

## Composition

- **[issue-triage](../issue-triage/SKILL.md)** — runs *first*. It hands its KEEP set to Mode C. It must not assign priority labels.
- **[github-issue-relationships](../github-issue-relationships/SKILL.md)** — the `addSubIssue` GraphQL link is the source of truth for hierarchy. The `epic` label is cosmetic, is reserved here, and is **not a type**: an epic still needs one of the nine.
- **The five issue-creating skills** (`skip-failed-test`, `critical-path-testing`, `tdd`, `test-fixer`, `pr-quality`) and the `debt-hunter` agent pass canon labels directly. `scripts/verify-canon.sh` fails CI if any of them drifts off-canon.

## Never

- Assign, create, or propose a priority label — including as a replacement when retiring one.
- Create a label the user hasn't approved. The hook blocks it; don't route around it via `gh api`.
- Delete a label before its issues have been carried across and the count verified at zero.
- Touch a reserved label.
- Invent an `area:` — derive it from what the repo already uses.
