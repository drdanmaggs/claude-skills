# RLS Test Patterns

## Pattern 1: User Cannot See Another User's Data

**This is the most critical RLS test.** If this fails, you have a data breach.

```typescript
describe('meal_plans RLS', () => {
  let userAClient: Awaited<ReturnType<typeof signInAs>>
  let userBClient: Awaited<ReturnType<typeof signInAs>>
  let testMealPlanIds: string[] = []
  let userAId: string
  let userBId: string

  beforeAll(async () => {
    userAClient = await signInAs(
      process.env.TEST_USER_A_EMAIL!,
      process.env.TEST_USER_A_PASSWORD!
    )
    userBClient = await signInAs(
      process.env.TEST_USER_B_EMAIL!,
      process.env.TEST_USER_B_PASSWORD!
    )

    const { data: { user: userA } } = await userAClient.auth.getUser()
    const { data: { user: userB } } = await userBClient.auth.getUser()
    userAId = userA!.id
    userBId = userB!.id

    testMealPlanIds = await createTestData('meal_plans', [
      { user_id: userAId, name: 'User A Week Plan', start_date: '2026-02-10' },
      { user_id: userBId, name: 'User B Week Plan', start_date: '2026-02-10' },
    ])
  })

  afterAll(async () => {
    await cleanupTestData('meal_plans', testMealPlanIds)
  })

  describe('SELECT policies', () => {
    it('should only return own meal plans for User A', async () => {
      const { data, error } = await userAClient
        .from('meal_plans')
        .select('name')

      expect(error).toBeNull()
      const names = (data ?? []).map((r) => r.name)
      expect(names).toContain('User A Week Plan')
      expect(names).not.toContain('User B Week Plan')
    })
  })

  describe('INSERT policies', () => {
    const insertedIds: string[] = []
    afterAll(async () => await cleanupTestData('meal_plans', insertedIds))

    it('should allow User A to create their own meal plan', async () => {
      const { data, error } = await userAClient
        .from('meal_plans')
        .insert({ user_id: userAId, name: 'New A Plan', start_date: '2026-03-01' })
        .select('id')
        .single()

      expect(error).toBeNull()
      if (data) insertedIds.push(data.id)
    })

    it('should prevent User A from creating a meal plan as User B', async () => {
      const { error } = await userAClient
        .from('meal_plans')
        .insert({ user_id: userBId, name: 'Sneaky Plan', start_date: '2026-03-01' })

      expect(error).not.toBeNull()
      expect(error!.message).toContain('row-level security policy')
    })
  })

  describe('UPDATE policies', () => {
    it('should silently fail when User A tries to update User B meal plan', async () => {
      // UPDATE violations don't throw — query succeeds but affects 0 rows
      const { data, error } = await userAClient
        .from('meal_plans')
        .update({ name: 'Hacked!' })
        .eq('id', testMealPlanIds[1])
        .select('name')

      expect(error).toBeNull()
      expect(data).toEqual([]) // No rows = RLS blocked it
    })
  })

  describe('DELETE policies', () => {
    it('should silently fail when User A tries to delete User B meal plan', async () => {
      // Same as UPDATE — no error, just empty result
      const { data, error } = await userAClient
        .from('meal_plans')
        .delete()
        .eq('id', testMealPlanIds[1])
        .select('id')

      expect(error).toBeNull()
      expect(data).toEqual([])
    })
  })
})
```

## Pattern 2: Anonymous Users Cannot Access Protected Data

```typescript
describe('anonymous access RLS', () => {
  const anonClient = createAnonClient()

  it('should return no meal plans for anonymous users', async () => {
    const { data, error } = await anonClient
      .from('meal_plans')
      .select('*')

    // Either returns empty or errors (depends on RLS setup)
    if (error) {
      expect(error.message).toBeDefined()
    } else {
      expect(data).toEqual([])
    }
  })

  it('should prevent anonymous users from creating data', async () => {
    const { error } = await anonClient
      .from('meal_plans')
      .insert({
        name: 'Anon Plan',
        start_date: '2026-03-01',
      })

    expect(error).not.toBeNull()
  })
})
```

## Pattern 3: Testing Joined/Nested Queries

Catches bugs where RLS works on parent table but leaks through joins.

```typescript
describe('nested data RLS', () => {
  let userAClient: Awaited<ReturnType<typeof signInAs>>
  let mealPlanIds: string[] = []
  let recipeIds: string[] = []

  beforeAll(async () => {
    userAClient = await signInAs(
      process.env.TEST_USER_A_EMAIL!,
      process.env.TEST_USER_A_PASSWORD!
    )

    const { data: { user: userA } } = await userAClient.auth.getUser()
    const { data: { user: userB } } = await (
      await signInAs(
        process.env.TEST_USER_B_EMAIL!,
        process.env.TEST_USER_B_PASSWORD!
      )
    ).auth.getUser()

    mealPlanIds = await createTestData('meal_plans', [
      { user_id: userA!.id, name: 'A Plan', start_date: '2026-02-10' },
      { user_id: userB!.id, name: 'B Plan', start_date: '2026-02-10' },
    ])

    recipeIds = await createTestData('recipes', [
      { meal_plan_id: mealPlanIds[0], name: 'A Recipe', user_id: userA!.id },
      { meal_plan_id: mealPlanIds[1], name: 'B Recipe', user_id: userB!.id },
    ])
  })

  afterAll(async () => {
    await cleanupTestData('recipes', recipeIds)
    await cleanupTestData('meal_plans', mealPlanIds)
  })

  it('should not leak User B recipes through meal plan join', async () => {
    const { data, error } = await userAClient
      .from('meal_plans')
      .select(`
        name,
        recipes (name)
      `)

    expect(error).toBeNull()

    const allRecipeNames = (data ?? [])
      .flatMap((mp) => (mp.recipes ?? []))
      .map((r) => r.name)

    expect(allRecipeNames).toContain('A Recipe')
    expect(allRecipeNames).not.toContain('B Recipe')
  })
})
```

## Pattern 4: RLS Coverage Audit

**Meta-test that checks all public tables have RLS enabled.** Catches "someone added a table and forgot" problems.

### Test Code

```typescript
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

### Required Migration

See `assets/coverage-audit.sql` for the database function this test depends on.

## Checklist: What to Test for Each Table

For every table with user data:

- [ ] Authenticated user can SELECT only their own rows
- [ ] Authenticated user can INSERT rows with their own user_id
- [ ] Authenticated user cannot INSERT rows with another user's user_id
- [ ] Authenticated user can UPDATE only their own rows
- [ ] Authenticated user cannot UPDATE another user's rows (check empty result, not error)
- [ ] Authenticated user can DELETE only their own rows
- [ ] Authenticated user cannot DELETE another user's rows (check empty result, not error)
- [ ] Anonymous user cannot SELECT any rows
- [ ] Anonymous user cannot INSERT any rows
- [ ] Nested queries (joins) do not leak data from other users
