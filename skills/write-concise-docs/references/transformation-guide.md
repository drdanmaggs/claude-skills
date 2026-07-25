# Transformation Guide: Verbose → Concise

This guide shows how to transform verbose Claude Code documentation into token-efficient, scannable rules using the everything-claude-code pattern.

## The Problem

Verbose docs waste context window tokens and are hard to scan:

- **User's test-user-isolation.md**: 170 lines
- **everything-claude-code average**: 30-70 lines
- **Difference**: 3x reduction needed

## Core Transformation Patterns

### 1. Replace Paragraphs with Bullets

**Before (verbose):**

```markdown
The anti-pattern involves hardcoding user IDs in test files. This creates several problems. First, tests become brittle because they depend on specific database state. Second, there's no isolation between tests because all tests share the same user. Third, tests are not self-sufficient and require specific database state to exist before they can run.
```

**After (concise):**

```markdown
**Problems with hardcoded user IDs:**

- Brittle - Tests fail if database reset
- No isolation - Tests interfere with each other
- Not self-sufficient - Requires specific database state
```

### 2. Use Action-Oriented Headers

**Before:**

```markdown
## What You Should Do Instead
```

**After:**

```markdown
## The Correct Pattern (✅ Do This)
```

### 3. Minimal Code Examples

**Before:** Show complete implementation with comments, setup, teardown, and multiple variations.

**After:** Show ONLY the key pattern difference:

```typescript
// ❌ BAD
const USER_ID = "hardcoded-uuid";

// ✅ GOOD
const userId = crypto.randomUUID();
```

### 4. Use Imperative Commands

**Before:** "You should consider creating..."
**After:** "ALWAYS create..." or "NEVER use..."

**Before:** "It's generally a good practice to..."
**After:** "Do this:" or "MANDATORY:"

### 5. Remove Redundancy

If you've said it once, don't repeat it. Cut:

- Introductory paragraphs explaining what the document is
- Summary sections that repeat earlier content
- Multiple examples showing the same concept
- Explanations of obvious things

### 6. Use Visual Markers

Add scannable markers:

- ✅ for correct patterns
- ❌ for anti-patterns
- ⚠️ for warnings
- CRITICAL, MANDATORY, ALWAYS, NEVER in bold

### 7. Link Don't Duplicate

If related info exists elsewhere, link to it:

**Before:** Copy the entire related pattern into your doc.

**After:**

```markdown
See also:

- `~/.claude/rules/testing.md` - Test patterns and isolation helpers
```

## Before/After Example

### Before (42 lines)

```markdown
# Test User Isolation - Avoid Hardcoded User IDs

## Introduction

When writing integration tests, it's important to ensure that each test is isolated from others. One common anti-pattern that violates this principle is hardcoding user IDs in test files.

## The Anti-Pattern

Here's an example of what NOT to do:

[Long code example with extensive comments...]

This approach has several problems:

1. Tests become brittle because they depend on specific database state...
   [Lengthy explanation of each problem...]

## Why This Is Bad

[Detailed explanation repeating the problems above...]

## The Correct Approach

Instead of hardcoding user IDs, you should create fresh users dynamically for each test...

[Another long code example with extensive comments...]

This approach has the following benefits:
[Lengthy list repeating inversions of the problems...]

## Related Best Practices

[More detailed explanations of related concepts...]
```

### After (18 lines)

````markdown
# Test User Isolation

**Core:** Create fresh auth users per test, never hardcode IDs.

## Anti-Pattern (❌)

```typescript
const USER_ID = "60658187-35f2-4acf-993e-4095f6386987"; // BRITTLE!
```
````

**Problems:** Brittle, no isolation, not self-sufficient.

## Correct Pattern (✅)

```typescript
const userId = crypto.randomUUID();
await supabase.from("auth.users").insert({ id: userId, ... });
```

**Benefits:** Self-sufficient, isolated, parallel-safe.

See: `~/.claude/rules/testing.md` (Data Management section) for createIsolatedTestHousehold()

```

## Token Savings

- **Before**: ~800 tokens
- **After**: ~250 tokens
- **Savings**: 70% reduction

## Checklist for Concise Docs

Before finalizing documentation:
- [ ] <50 lines (aim for 30-40)
- [ ] No paragraph longer than 3 lines
- [ ] Code examples <10 lines each
- [ ] Headers are action-oriented
- [ ] Using ALWAYS/NEVER/MANDATORY
- [ ] Visual markers (✅❌⚠️) present
- [ ] No redundant explanations
- [ ] Links replace duplicated content
- [ ] Every word justifies its token cost
```
