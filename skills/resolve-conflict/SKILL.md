---
name: resolve-conflict
description: >
  Resolves merge conflicts on the current PR branch after another branch has
  been merged to main. Rebases intelligently using sequential thinking to
  analyse each conflict, resolving automatically wherever intent is clear.
  Only stops for user input when a conflict is genuinely ambiguous. After
  resolving, verifies locally, pushes, and polls CI until all checks pass.
  Announces "READY TO MERGE" in ASCII art when done. Use when a PR has a
  merge conflict, when you've been asked to rebase, or after merging another
  branch causes a conflict on an in-flight PR.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(pnpm:*), Bash(bun:*), Read, Grep, Glob, Edit
---

# Resolve Conflict

Autonomous conflict resolution with sequential thinking. Rebases onto main,
resolves conflicts intelligently, verifies, pushes, and polls CI to completion.

The only permitted interruption is a conflict that is genuinely ambiguous after
sequential-thinking analysis. Everything else resolves automatically.

---

## Stage 0: Initialise

Run in parallel:
```bash
git branch --show-current
git status --short
git log origin/main..HEAD --oneline
gh pr view --json number,title,url,state,statusCheckRollup
```

Capture:
- `BRANCH` — current branch name
- `PR_NUMBER` — for CI polling
- `PR_URL` — for final summary

Check that a PR exists and the branch is not main/master. If no PR exists,
tell the user and stop.

---

## Stage 1: Fetch and Attempt Rebase

```bash
git fetch origin main
git rebase origin/main
```

If rebase exits clean (no conflicts) → skip to Stage 3.

If conflicts exist, continue to Stage 2.

---

## Stage 2: Conflict Resolution Loop

**This is a loop. Repeat until `git rebase --continue` succeeds with no
remaining conflicts.**

For each conflicted file detected by `git status --short` (lines starting
with `UU`, `AA`, `DD`, `AU`, `UA`):

### Step 1 — Read the conflict

Read the full file. Identify all conflict markers (`<<<<<<<`, `=======`,
`>>>>>>>`). For each conflict hunk, capture:
- **Ours** (HEAD / current branch changes)
- **Theirs** (incoming / main changes)

Also read the surrounding context — what the file is for and what both
sides are trying to accomplish.

### Step 2 — Sequential thinking analysis

Use `mcp__sequential-thinking__sequentialthinking` to reason through the
conflict:

1. **What did ours change?** Summarise the intent of the current branch's
   change in this hunk.
2. **What did theirs change?** Summarise the intent of main's change in
   this hunk.
3. **Are the changes independent?** Can both be kept without contradiction?
4. **Is one a superset of the other?** Does one version already include
   what the other does?
5. **Do they conflict semantically?** Would keeping both break correctness,
   types, tests, or logic?
6. **Determine resolution:**
   - If independent → keep both (ours on top of theirs, or merge sensibly)
   - If ours supersedes theirs → keep ours
   - If theirs supersedes ours → keep theirs
   - If genuinely ambiguous → flag for user (this is the ONLY permitted stop)

Resolution is **ambiguous** only when the changes affect the same logic in
incompatible ways AND the correct merge cannot be determined from the code
and surrounding context alone. Do NOT flag as ambiguous just because the
conflict looks complex — think it through fully first.

### Step 3 — Apply resolution

Edit the file to remove all conflict markers and apply the chosen resolution.
Do NOT leave any `<<<<<<<`, `=======`, or `>>>>>>>` markers in the file.

### Step 4 — Stage the file

```bash
git add <file>
```

### Step 5 — Check for remaining conflicts

```bash
git status --short
```

If more conflicted files remain, go back to Step 1 for the next file.
Once all files are staged, continue.

### Step 6 — Continue rebase

```bash
git rebase --continue
```

If git reports more conflicts (another commit in the rebase stack) →
return to the top of this loop for the new conflicted files.

If `--continue` succeeds → proceed to Stage 3.

---

## Stage 3: Local Verification

Detect package manager from lockfile (`bun.lockb` → bun, `pnpm-lock.yaml`
→ pnpm, `yarn.lock` → yarn, otherwise npm). Run:

```bash
{pm} run lint && {pm} run type-check
```

Run tests:
```bash
{pm} run vitest run   # or {pm} test if no vitest script
```

If any check fails:
- Lint / type error → fix directly, re-verify
- Test failure → use sequential thinking to diagnose whether the conflict
  resolution introduced the failure; fix the resolution if so, otherwise
  apply a targeted fix

Do not push until all three checks pass.

---

## Stage 4: Push

```bash
git push origin HEAD --force-with-lease
```

`--force-with-lease` is safe here: we are the only author of this branch
and have just rebased. It refuses to push if the remote has diverged
unexpectedly, protecting against accidental overwrites.

Record `PUSH_TIME`:
```bash
PUSH_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

---

## Stage 5: CI Loop

**Infinite loop. Poll every 30 seconds until all checks pass.**

```bash
gh pr view $PR_NUMBER --json statusCheckRollup
```

States:
- `PENDING` / `IN_PROGRESS` → keep polling
- `SUCCESS` for all checks → exit loop → proceed to Finale
- `FAILURE` / `ERROR` on any check → diagnose and fix:
  - Test failure → sequential thinking to identify root cause, then fix
  - Type / lint / build error → fix directly
  - After fixing: verify locally, push (`--force-with-lease`), resume polling

Do NOT wait for a code review in this stage. The goal is CI green.

---

## Finale: Ready to Merge

Output a brief summary:
- Conflicts resolved: N files, M hunks
- Resolution method for each file (merged / kept ours / kept theirs)
- CI checks: all passing
- PR URL

Then output the ASCII art:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ██████╗ ███████╗ █████╗ ██████╗ ██╗   ██╗
  ██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
  ██████╔╝█████╗  ███████║██║  ██║ ╚████╔╝
  ██╔══██╗██╔══╝  ██╔══██║██║  ██║  ╚██╔╝
  ██║  ██║███████╗██║  ██║██████╔╝   ██║
  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝    ╚═╝

  ████████╗ ██████╗
  ╚══██╔══╝██╔═══██╗
     ██║   ██║   ██║
     ██║   ██║   ██║
     ██║   ╚██████╔╝
     ╚═╝    ╚═════╝

  ███╗   ███╗███████╗██████╗  ██████╗ ███████╗
  ████╗ ████║██╔════╝██╔══██╗██╔════╝ ██╔════╝
  ██╔████╔██║█████╗  ██████╔╝██║  ███╗█████╗
  ██║╚██╔╝██║██╔══╝  ██╔══██╗██║   ██║██╔══╝
  ██║ ╚═╝ ██║███████╗██║  ██║╚██████╔╝███████╗
  ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
