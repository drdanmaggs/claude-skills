# RLS Testing Gotchas

## CRITICAL: UPDATE and DELETE Don't Throw Errors

**This is the #1 source of false-passing RLS tests.**

When RLS blocks an operation:
- **INSERT**: Throws error with "row-level security policy" message
- **UPDATE**: Succeeds but affects zero rows
- **DELETE**: Succeeds but affects zero rows

### Wrong (Will Pass Even When RLS is Broken)

```typescript
it('should prevent cross-user update', async () => {
  const { error } = await userAClient
    .from('meal_plans')
    .update({ name: 'Hacked!' })
    .eq('id', userBMealPlanId)

  // ❌ error will be null even if the update was blocked!
  expect(error).not.toBeNull() // THIS FAILS
})
```

### Correct (Checks for Empty Result)

```typescript
it('should prevent cross-user update', async () => {
  const { data, error } = await userAClient
    .from('meal_plans')
    .update({ name: 'Hacked!' })
    .eq('id', userBMealPlanId)
    .select('name')

  expect(error).toBeNull()
  expect(data).toEqual([]) // ✅ No rows affected = RLS working
})
```

**Rule**: For UPDATE/DELETE tests, always use `.select()` and assert `data` is empty array, not that `error` exists.

## persistSession: false Is Critical

Without `persistSession: false`, the service role client and user client share session storage. The service role token leaks into the user client, bypassing RLS.

**Result**: Your tests pass even when policies are broken.

```typescript
// ✅ REQUIRED for both clients
export const serviceClient = createClient(url, serviceKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
})

export function createUserClient() {
  return createClient(url, anonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  })
}
```

## Test Data Isolation

Tests should not assume the database is empty. Always filter assertions to known test data:

```typescript
// ❌ FRAGILE — breaks if any other data exists
expect(data).toHaveLength(1)

// ✅ ROBUST — checks for specific known data
const names = (data ?? []).map((r) => r.name)
expect(names).toContain('User A Week Plan')
expect(names).not.toContain('User B Week Plan')
```

## Test User Creation

Create test users manually in your Supabase branch before running tests. Don't create programmatically — it adds complexity and requires email confirmation.

For CI, use service role client:

```typescript
const { data, error } = await serviceClient.auth.admin.createUser({
  email: 'testuser@test.com',
  password: 'secure-password',
  email_confirm: true, // Skip email verification
})
```

## Network Dependency

Tests require the remote Supabase branch to be running. If paused, tests fail with network errors (not RLS errors).

Consider a health check:

```typescript
export async function checkConnection(): Promise<void> {
  const { error } = await serviceClient
    .from('meal_plans')
    .select('id')
    .limit(1)

  if (error) {
    throw new Error(
      `Cannot connect to Supabase branch: ${error.message}. Is the branch running?`
    )
  }
}
```

## Deletion Order in Cleanup

Always delete children before parents to avoid FK constraint errors:

```typescript
afterAll(async () => {
  // ✅ CORRECT ORDER
  await supabase.from('recipes').delete().in('id', recipeIds) // child
  await supabase.from('meal_plans').delete().in('id', mealPlanIds) // parent
})
```

Check your schema for FK constraints and `ON DELETE` behavior (RESTRICT requires manual delete, CASCADE is automatic).
