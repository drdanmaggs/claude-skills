# Test Patterns for Retrofit

Best practices for writing good, non-flaky tests when retrofitting coverage.

## Core Principles

1. **Integration over unit** - Test behavior, not implementation
2. **Avoid over-mocking** - Mock external boundaries only
3. **Test isolation** - Each test creates its own data
4. **Self-cleaning** - Tests clean up after themselves

---

## Server Actions Pattern (Next.js)

**Never test server actions directly in unit tests.**

### Anti-Pattern (❌)

```typescript
// ❌ Mocking 3 framework internals just to call action
vi.mock("@/lib/supabase/server", ...);
vi.mock("@/lib/dal", ...);
vi.mock("next/cache", ...);
const result = await addTopLevelCategory("Test");
```

### Correct Pattern (✅)

```typescript
// actions.ts - thin wrapper (NOT unit tested, tested via E2E)
"use server";
export async function addTopLevelCategory(name: string) {
  await requireAdmin();
  const supabase = await createClient();
  const result = await addTopLevelCategoryLogic(supabase, name);
  if (result.success) revalidatePath("/admin/categories-review");
  return result;
}

// logic.ts - business logic (unit tested)
export async function addTopLevelCategoryLogic(
  supabase: SupabaseClient,
  name: string
) {
  // All database operations here
  // This is what you test!
}

// test - zero mocks
const supabase = createClient(URL, SERVICE_ROLE_KEY);
const result = await addTopLevelCategoryLogic(supabase, testName("Category"));
expect(result.success).toBe(true);
```

**Why:** Server actions have framework dependencies (cookies, revalidation, auth). Extract logic, test that.

---

## Test Data Isolation

**Ban hardcoded test IDs.**

### Anti-Pattern (❌)

```typescript
const USER_ID = "hardcoded-uuid";
await supabase.from("records").insert({ owner_id: USER_ID });
```

**Problems:** Brittle, no isolation, requires specific DB state, FK errors.

### Correct Pattern (✅)

```typescript
import { createIsolatedTestHousehold } from '@/tests/helpers/isolated-test-household';

let household: IsolatedTestHousehold;

beforeAll(async () => {
  household = await createIsolatedTestHousehold(supabase);
});

afterAll(async () => {
  await cleanupIsolatedTestHousehold(supabase, household.householdId);
});

// Use household.householdId, household.userId, etc.
```

**If no isolation helper exists:**

```typescript
const userId = crypto.randomUUID();
await supabase.from("auth.users").insert({
  id: userId,
  email: `test-${crypto.randomUUID()}@example.com`,
});
```

**Benefits:** Self-sufficient, isolated, parallel-safe.

---

## Self-Cleaning Tests

**Tests MUST clean up their data.**

### Pattern

```typescript
let recordIds: string[] = [];

afterAll(async () => {
  // DELETE CHILDREN FIRST (reverse FK order)
  await supabase.from("child_records").delete().in("id", childIds);
  await supabase.from("parent_records").delete().in("id", parentIds);
});

it("test", async () => {
  const record = await supabase.from("records").insert({...}).single();
  recordIds.push(record.id); // TRACK IT!
});
```

### Test Naming Helper

```typescript
export function testName(desc: string) {
  return `__TEST__${crypto.randomUUID().slice(0, 8)}__${desc}`;
}

// Usage
const record = await supabase.from("records")
  .insert({ name: testName("Record") });
```

**Why:** `afterAll` doesn't run on Ctrl+C or crashes. Pre-test cleanup scripts can find `__TEST__` prefix.

---

## Mock Guidance

| Mock target | Keep? | Reason |
|-------------|-------|--------|
| Supabase client | **REMOVE** | Pass real client to logic function |
| Auth/session | **REMOVE** | Tested via E2E |
| `next/cache` | **REMOVE** | Revalidation tested via E2E |
| Vercel AI SDK | **KEEP** | External service boundary |
| `@langfuse/*` | **KEEP** | External service boundary |
| Stripe API | **KEEP** | External service boundary |

**Rule:** Mock external APIs. Don't mock your own framework wrappers.

---

## Type Safety

### No `any` Types (❌)

```typescript
// ❌ BANNED
const result: any = await fetchData();
const data = result as any;
```

### Use `unknown` with Validation (✅)

```typescript
// ✅ Correct
function processData(data: unknown) {
  if (typeof data === 'string') {
    return data.toUpperCase();
  }
  throw new Error('Invalid data type');
}
```

**Why:** `any` silences type warnings. Type warnings catch real bugs.

---

## Flakiness Prevention

### Avoid Arbitrary Timeouts (❌)

```typescript
await new Promise(r => setTimeout(r, 1000));
```

### Use Proper Waits (✅)

```typescript
await waitFor(() => expect(element).toBeVisible());
```

### Mock Time (✅)

```typescript
vi.setSystemTime(new Date('2026-02-05'));
// ... test code
vi.useRealTimers();
```

### Flexible Assertions (✅)

```typescript
// ❌ Flaky
expect(items).toEqual([1, 2, 3]); // Order-dependent

// ✅ Stable
expect(items).toEqual(expect.arrayContaining([1, 2, 3]));
```

---

## Quick Reference

**When retrofitting tests:**

1. ✅ Extract logic from server actions
2. ✅ Use dynamic test data (no hardcoded IDs)
3. ✅ Track IDs and clean up in `afterAll`
4. ✅ Mock external APIs only
5. ✅ Use `unknown` instead of `any`
6. ✅ Avoid arbitrary timeouts
7. ✅ Test behavior, not implementation

**Default mindset:** "Could this test fail inconsistently?" If yes, fix the pattern.

---

## BANNED PATTERNS - Never Use These

Make anti-patterns explicit with side-by-side examples.

### ❌ Hardcoded Test Data

```typescript
// ❌ BANNED - Brittle, causes collisions
const userId = "123e4567-e89b-12d3-a456-426614174000";
const testEmail = "test@example.com";

// ✅ CORRECT - Dynamic, isolated
const userId = crypto.randomUUID();
const testEmail = `test-${crypto.randomUUID()}@example.com`;
```

**Why banned:** Hardcoded IDs require specific DB state, cause collisions in parallel tests, break with FK constraints.

### ❌ Arbitrary Waits

```typescript
// ❌ BANNED - Flaky timing
await new Promise(r => setTimeout(r, 1000));

// ✅ CORRECT - Condition-based
await waitFor(() => expect(element).toBeVisible());
```

**Why banned:** Race conditions on slow CI, inconsistent pass/fail, masks real timing issues.

### ❌ Missing Cleanup

```typescript
// ❌ BANNED - Test pollution
it('creates record', async () => {
  await db.insert({ id: testId });
  expect(result).toBeTruthy();
  // No cleanup!
});

// ✅ CORRECT - Self-cleaning
let createdIds: string[] = [];

afterAll(async () => {
  await db.delete().in('id', createdIds);
});

it('creates record', async () => {
  const record = await db.insert({ id: testId });
  createdIds.push(record.id);  // Track for cleanup
  expect(result).toBeTruthy();
});
```

**Why banned:** Database pollution, test interdependence, CI failures from stale data.

### ❌ Overly Strict Assertions

```typescript
// ❌ BANNED - Breaks on dynamic data
expect(result).toEqual([
  { id: 'abc-123', createdAt: '2024-01-01T00:00:00.000Z' }
]);

// ✅ CORRECT - Flexible
expect(result).toEqual(expect.arrayContaining([
  expect.objectContaining({
    id: expect.any(String),
    createdAt: expect.any(String)
  })
]));
```

**Why banned:** UUIDs and timestamps are dynamic, order may vary, breaks on unrelated changes.

### ❌ Testing Implementation Details

```typescript
// ❌ BANNED - Brittle, couples to implementation
expect(component.state.internalCounter).toBe(5);

// ✅ CORRECT - Test behavior
await userEvent.click(incrementButton);
expect(screen.getByText('Count: 5')).toBeInTheDocument();
```

**Why banned:** Breaks during refactoring, doesn't test user-facing behavior, encourages bad architecture.
