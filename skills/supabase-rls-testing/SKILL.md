---
name: supabase-rls-testing
description: Set up and write Vitest integration tests for Supabase Row Level Security (RLS) policies. Use when adding RLS tests, testing database security, verifying user data isolation, or checking RLS coverage. Covers test infrastructure setup, the critical UPDATE/DELETE gotcha (silent failures vs errors), RLS coverage audits, and table-specific test patterns.
---

# Supabase RLS Testing

Test Row Level Security policies using Vitest integration tests against a remote Supabase branch.

## Why This Matters

RLS policies are the security boundary between users' data. A broken policy means User A can see User B's data. Automated tests catch these bugs before production.

## First: Check Existing Setup

Before starting, check what's already in place:

**Test infrastructure:**
- Check for `vitest.integration.config.ts` or integration test config in `vitest.config.ts`
- Check for `tests/utils/supabase-test-clients.ts` or similar
- Check for `tests/helpers/isolated-test-household.ts` or similar (household isolation helpers)
- Check for `.env.test` or `.env.local` with test credentials

**Existing RLS tests:**
- Search for `*.test.ts` files in `tests/integration/rls/` or `tests/rls/`
- Grep for `serviceClient.rpc('check_rls_coverage')` to find coverage audit
- Check `supabase/migrations/*rls*` for existing RLS-related migrations

**Household isolation patterns:**
- Grep for `createIsolatedTestHousehold` or similar functions
- Check if project uses dynamic user creation (better!) vs. manual test users
- Look for multi-user test helpers (User A vs User B patterns)

**Based on what exists:**
- **No infrastructure**: Follow workflow from Step 1
- **Infrastructure exists**: Skip to Step 3 (add table-specific tests)
- **Coverage audit missing**: Start at Step 1, skip Step 2
- **Adding tests for new table**: Go directly to Step 3
- **Project has household helpers**: Adapt Step 2 to use existing patterns instead of templates

## Workflow

### 1. Add RLS Coverage Audit (DO THIS FIRST)

The meta-test that catches missing policies before anything else.

**Add the database function:**

1. Create migration: `supabase/migrations/YYYYMMDDHHMMSS_add_rls_coverage_check.sql`
2. Copy SQL from `assets/coverage-audit.sql`
3. Apply: `supabase db push`

**Add the test:**

```typescript
// src/tests/rls/rls-coverage.integration.test.ts
import { describe, it, expect } from 'vitest'
import { serviceClient } from '../utils/supabase-test-clients'

describe('RLS coverage', () => {
  it('should have RLS enabled on all public tables', async () => {
    const { data, error } = await serviceClient.rpc('check_rls_coverage')

    expect(error).toBeNull()

    const unprotected = (data ?? []).filter(
      (t: { rls_enabled: boolean }) => !t.rls_enabled
    )

    if (unprotected.length > 0) {
      const names = unprotected
        .map((t: { table_name: string }) => t.table_name)
        .join(', ')
      throw new Error(`Tables without RLS enabled: ${names}`)
    }
  })
})
```

Run this test. If it fails, enable RLS on the flagged tables before continuing.

### 2. Set Up Test Infrastructure

**Skip if infrastructure already exists** (check in "First: Check Existing Setup" above).

**IMPORTANT: Adapt to existing patterns.** If the project already has household isolation helpers (like `createIsolatedTestHousehold`), use those instead of creating manual test users. Dynamic user creation is better than static test accounts.

**Environment variables** (`.env.test` or `.env.local`, check project convention):

```env
SUPABASE_URL=https://your-branch-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Only if NOT using dynamic user creation:
TEST_USER_A_EMAIL=testusera@test.com
TEST_USER_A_PASSWORD=secure-password-123
TEST_USER_B_EMAIL=testuserb@test.com
TEST_USER_B_PASSWORD=secure-password-456
```

**If using dynamic user creation** (via helpers like `createIsolatedTestHousehold`), skip manual test user setup. The helpers will create unique users per test suite automatically.

**Vitest config:**

Copy `assets/vitest.integration.config.ts` to project root. Add npm script:

```json
{
  "scripts": {
    "test:integration": "vitest run --config vitest.integration.config.ts"
  }
}
```

**Test utilities:**

1. **If project has household helpers**: Create multi-user wrapper (see `assets/rls-multi-user-clients.ts` for pattern)
2. **If starting from scratch**: Copy `assets/supabase-test-clients.ts` and `assets/rls-test-helpers.ts` to `tests/utils/` (update Database type import)

See [references/architecture.md](references/architecture.md) for details on the two-client setup.

### 3. Add Table-Specific Tests

For each table with user data, write tests covering:

- User can SELECT only their own rows
- User can INSERT rows with their own user_id
- User cannot INSERT rows with another user's user_id
- User cannot UPDATE another user's rows
- User cannot DELETE another user's rows
- Anonymous user cannot access any rows
- Nested queries don't leak data through joins

See [references/test-patterns.md](references/test-patterns.md) for complete examples.

## CRITICAL: The UPDATE/DELETE Gotcha

**Most important thing to know about RLS testing.**

When RLS blocks operations:

- **INSERT**: Throws error ✅
- **UPDATE**: Succeeds but affects zero rows ⚠️
- **DELETE**: Succeeds but affects zero rows ⚠️

**Wrong** (will pass even when RLS is broken):

```typescript
it('should prevent cross-user update', async () => {
  const { error } = await userAClient
    .from('meal_plans')
    .update({ name: 'Hacked!' })
    .eq('id', userBMealPlanId)

  expect(error).not.toBeNull() // ❌ error will be null!
})
```

**Correct** (checks empty result):

```typescript
it('should prevent cross-user update', async () => {
  const { data, error } = await userAClient
    .from('meal_plans')
    .update({ name: 'Hacked!' })
    .eq('id', userBMealPlanId)
    .select('name')

  expect(error).toBeNull()
  expect(data).toEqual([]) // ✅ No rows = RLS working
})
```

**Rule**: For UPDATE/DELETE tests, always use `.select()` and assert `data` is empty array.

See [references/gotchas.md](references/gotchas.md) for other common pitfalls.

## Test Naming Conventions

Follow behavioral naming patterns from TDD skill's [test-standards.md](~/.claude/skills/tdd/references/test-standards.md#test-naming):

**Start with "should"** - describes behavior, not implementation:

```typescript
// ✅ Good
it('should prevent User A from reading User B's chat sessions', ...)
it('should allow User B to access their own chat sessions', ...)
it('should prevent cross-household updates [GOTCHA: returns empty array]', ...)

// ❌ Bad - doesn't start with "should"
it('User A cannot read User B data', ...)
it('blocks cross-household access', ...)
```

**Permission/RLS naming patterns:**
- `should allow [role] to [action] their own [resource]`
- `should prevent [role] from accessing [other user's resource]`
- `should return empty array when RLS blocks [operation]` (UPDATE/DELETE)
- `should throw error when RLS blocks [operation]` (INSERT)

**Context from describe() blocks:**

```typescript
describe('chat_sessions table', () => {
  it('should prevent User A from reading User B's sessions', ...) // ✅
  // Reads: "chat_sessions table should prevent User A from..."
})
```

**When a test fails in CI, the name should be the bug report.**

## References

- [test-patterns.md](references/test-patterns.md) - Four core test patterns with examples
- [gotchas.md](references/gotchas.md) - UPDATE/DELETE gotcha and other pitfalls
- [architecture.md](references/architecture.md) - Client setup and environment config

## Assets

- [vitest.integration.config.ts](assets/vitest.integration.config.ts) - Vitest config template
- [supabase-test-clients.ts](assets/supabase-test-clients.ts) - Two-client setup (manual users)
- [rls-multi-user-clients.ts](assets/rls-multi-user-clients.ts) - Multi-user setup (dynamic users with household helpers)
- [rls-test-helpers.ts](assets/rls-test-helpers.ts) - Test helper functions
- [coverage-audit.sql](assets/coverage-audit.sql) - RLS coverage check migration
