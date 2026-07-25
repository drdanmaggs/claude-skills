---
name: concise-docs
description: Write concise, token-efficient Claude Code documentation (rules, guides, docs). Use when creating or refactoring documentation files in ~/.claude/rules/, ~/.claude/docs/, or project CLAUDE.md files. Transforms verbose documentation into scannable, action-oriented format following everything-claude-code patterns. Auto-trigger when user mentions "docs are too long", "verbose documentation", "optimize context", or asks to write new rules/guides.
---

# Concise Documentation Writer

Write token-efficient, scannable Claude Code documentation following proven everything-claude-code patterns.

## Target: 30-70 Lines Per Doc

**Problem:** Verbose docs waste context window and are hard to scan.
**Solution:** Apply aggressive compression without losing clarity.

## Core Principles

### 1. Replace Paragraphs with Bullets

❌ **Verbose:**

```markdown
The anti-pattern involves hardcoding user IDs which creates problems.
First, tests become brittle. Second, there's no isolation. Third...
```

✅ **Concise:**

```markdown
**Problems:**

- Brittle - Tests fail if database reset
- No isolation - Tests interfere
- Not self-sufficient - Requires specific state
```

### 2. Use Action-Oriented Language

**Commands, not suggestions:**

- ALWAYS / NEVER / MANDATORY (bold)
- "Do this:" not "You should consider..."
- "Ban X" not "It's generally better to avoid X"

### 3. Minimal Code Examples

Show ONLY the key pattern difference:

```typescript
// ❌ BAD
const USER_ID = "hardcoded-uuid";

// ✅ GOOD
const userId = crypto.randomUUID();
```

Don't include:

- Full implementations
- Setup/teardown boilerplate
- Multiple variations of same concept
- Extensive comments

### 4. Visual Markers for Scanning

- ✅ Correct patterns
- ❌ Anti-patterns
- ⚠️ Warnings
- **CRITICAL** / **MANDATORY** in bold

### 5. Link Don't Duplicate

If info exists elsewhere, link to it:

```markdown
See: `~/.claude/rules/related-doc.md` for details
```

Don't copy entire sections from other docs.

### 6. Ruthless Redundancy Removal

**Cut immediately:**

- Introductory paragraphs explaining what doc is
- Summary sections repeating earlier content
- "TL;DR" sections (doc should already be concise)
- "Learned From" anecdotes (not actionable)
- Multiple examples of same concept
- Explanations of obvious things
- "In this section we will..." meta-commentary

### 7. Structure for Speed

```markdown
# Title

**Core principle:** One-line summary.

## Anti-Pattern (❌)

[Minimal code example]

## Correct Pattern (✅)

[Minimal code example]

## Related

- Link to doc 1
- Link to doc 2
```

## Workflow

### Step 1: Analyze Existing Doc

If refactoring verbose doc:

1. Identify core message (1-2 sentences)
2. Find anti-pattern example
3. Find correct pattern example
4. Note related links

### Step 2: Apply Compression

**For each section:**

- Can this be bullets? → Make it bullets
- Is this redundant? → Delete
- Is this longer than 3 lines? → Compress
- Can I link instead? → Link

**For code examples:**

- Remove all but key difference
- Max 10 lines per example
- No comments unless critical

### Step 3: Validate

**Final doc must:**

- [ ] <50 lines (aim 30-40)
- [ ] No paragraph >3 lines
- [ ] Action-oriented headers
- [ ] Visual markers present
- [ ] Links replace duplication
- [ ] Every word justifies token cost

## Example Transformation

### Before (42 lines, ~800 tokens)

```markdown
# Test User Isolation - Avoid Hardcoded User IDs

## Introduction

When writing integration tests, it's important to ensure...
[3 paragraphs explaining context]

## The Anti-Pattern

Here's an example of what NOT to do:
[Long code with extensive comments]

This approach has several problems:

1. Tests become brittle because...
   [Lengthy explanation of each problem]

## The Correct Approach

Instead of hardcoding, create fresh users...
[Another long code example]

Benefits include:
[Lengthy list repeating problem inversions]
```

### After (18 lines, ~250 tokens - 70% reduction)

````markdown
# Test User Isolation

**Core:** Create fresh auth users per test, never hardcode IDs.

## Anti-Pattern (❌)

```typescript
const USER_ID = "60658187-..."; // BRITTLE!
```
````

**Problems:** Brittle, no isolation, not self-sufficient.

## Correct Pattern (✅)

```typescript
const userId = crypto.randomUUID();
await supabase.from("auth.users").insert({ id: userId, ... });
```

**Benefits:** Self-sufficient, isolated, parallel-safe.

See: `~/.claude/rules/testing.md` (Data Management section) for helper

```

## Resources

### references/transformation-guide.md

Detailed transformation patterns with more before/after examples. Read when:
- First time using this skill
- Unsure how to compress specific pattern
- Need more examples

### references/example-*.md

Real examples from everything-claude-code repo showing ideal format:
- `example-testing.md` - Testing requirements (30 lines)
- `example-coding-style.md` - Code quality standards (70 lines)
- `example-patterns.md` - Common patterns (55 lines)

Use as templates for structure and tone.

## Quick Reference

**Length targets:**
- Rules: 30-50 lines
- Guides: 40-70 lines
- CLAUDE.md sections: 20-40 lines

**Format:**
- Headers: Action-oriented (##)
- Content: Bullets > paragraphs
- Code: <10 lines per example
- Links: Replace duplication

**Tone:**
- ALWAYS / NEVER / MANDATORY
- Imperative commands
- Zero fluff
```
