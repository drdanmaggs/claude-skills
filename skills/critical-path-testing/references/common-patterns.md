# Common Test Patterns

**Purpose:** Reusable test patterns from test-fixer learnings

**Usage:** Writers include these patterns based on planner recommendations

---

## Pattern: worker_fixtures

**When:** All integration and E2E tests (MANDATORY)

**Integration Test:**

```typescript
import { test, expect } from "@/tests/helpers/vitest-worker-fixture";
import { createServiceRoleClient } from "@/lib/supabase/server";

test("creates data in isolated household", async ({ workerHousehold }) => {
  const supabase = createServiceRoleClient();

  const { data, error } = await supabase
    .from("meals")
    .insert({
      household_id: workerHousehold.householdId,
      name: testName("Meal"),
    })
    .select()
    .single();

  expect(error).toBeNull();
  expect(data).toBeDefined();
  expect(data.household_id).toBe(workerHousehold.householdId);
});
```

**E2E Test:**

```typescript
import { test, expect } from "@/tests/e2e/fixtures/auth-fixture";

test("user flow", async ({ page, workerAuth }) => {
  await page.goto("/login");
  await page.fill('input[name="email"]', workerAuth.email);
  await page.fill('input[name="password"]', workerAuth.password);
  await page.click('button[type="submit"]');

  await expect(page).toHaveURL(/\/dashboard/);
});
```

**Benefits:**

- Cleanup runs even on crash/timeout
- Parallel execution safe
- No manual beforeAll/afterAll

**Reference:** `~/.claude/rules/testing.md` (Data Management section)

---

## Pattern: worker_fixtures_with_retry

**When:** Supabase auth operations in parallel tests

**Problem:** Auth API rate limiting causes cascading failures

**Solution:**

```typescript
import { test, expect } from "@/tests/helpers/vitest-worker-fixture";
import { createServiceRoleClient } from "@/lib/supabase/server";

async function signInWithRetry(
  supabase: SupabaseClient,
  email: string,
  password: string,
  maxAttempts = 3,
) {
  for (let i = 0; i < maxAttempts; i++) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (!error) return { data, error: null };

    if (error.message?.includes("rate limit")) {
      const delay = Math.pow(2, i) * 1000; // 1s, 2s, 4s
      await new Promise((resolve) => setTimeout(resolve, delay));
      continue;
    }

    return { data: null, error };
  }

  throw new Error(`Failed to sign in after ${maxAttempts} attempts`);
}

test("handles auth with retry logic", async ({ workerHousehold }) => {
  const supabase = createServiceRoleClient();

  const { data, error } = await signInWithRetry(
    supabase,
    workerHousehold.email,
    workerHousehold.password,
  );

  expect(error).toBeNull();
  expect(data.user).toBeDefined();
});
```

**Reference:** `/docs/test-debugging-deep-dive.md` (Supabase Auth Rate Limiting)

---

## Pattern: error_checking

**When:** ALL database operations (MANDATORY)

**Problem:** Supabase returns `{ data: null, error }` instead of throwing

**Solution:**

```typescript
test("checks error on all DB operations", async ({ workerHousehold }) => {
  const supabase = createServiceRoleClient();

  // INSERT
  const { data: inserted, error: insertError } = await supabase
    .from("categories")
    .insert({
      household_id: workerHousehold.householdId,
      name: testName("Category"),
    })
    .select()
    .single();

  expect(insertError).toBeNull(); // CRITICAL
  expect(inserted).toBeDefined();

  // UPDATE
  const { data: updated, error: updateError } = await supabase
    .from("categories")
    .update({ name: testName("Updated") })
    .eq("id", inserted.id)
    .select()
    .single();

  expect(updateError).toBeNull(); // CRITICAL
  expect(updated.name).toContain("Updated");

  // DELETE
  const { error: deleteError } = await supabase
    .from("categories")
    .delete()
    .eq("id", inserted.id);

  expect(deleteError).toBeNull(); // CRITICAL
});
```

**Common error scenarios:**

- RLS policy denies operation → `error` set, `data` is null
- FK constraint violation → `error` set
- Invalid data type → `error` set

**Without error checking:** Test continues with null data → "Cannot read properties of null"

---

## Pattern: cascade_verification

**When:** Testing delete operations with foreign keys

**Problem:** CASCADE DELETE can delete other workers' data

**Solution:**

```typescript
test("verifies cascade behavior manually", async ({ workerHousehold }) => {
  const supabase = createServiceRoleClient();

  // Create parent
  const { data: category, error: categoryError } = await supabase
    .from("categories")
    .insert({
      household_id: workerHousehold.householdId,
      name: testName("Category"),
    })
    .select()
    .single();

  expect(categoryError).toBeNull();

  // Create child
  const { data: item, error: itemError } = await supabase
    .from("category_items")
    .insert({ category_id: category.id, name: testName("Item") })
    .select()
    .single();

  expect(itemError).toBeNull();

  // Delete child FIRST (manual, not CASCADE)
  const { error: deleteItemError } = await supabase
    .from("category_items")
    .delete()
    .eq("id", item.id);

  expect(deleteItemError).toBeNull();

  // Verify child deleted
  const { data: itemCheck } = await supabase
    .from("category_items")
    .select()
    .eq("id", item.id)
    .maybeSingle();

  expect(itemCheck).toBeNull();

  // Then delete parent
  const { error: deleteCategoryError } = await supabase
    .from("categories")
    .delete()
    .eq("id", category.id);

  expect(deleteCategoryError).toBeNull();
});
```

**Why not use CASCADE:**

- Worker A's CASCADE can delete Worker B's children mid-test
- Causes "Cannot read properties of null" in parallel execution
- Only happens in CI (sequential local tests don't catch it)

**Reference:** `~/.claude/rules/self-cleaning-tests.md`

---

## Pattern: retry_logic

**When:** External service calls (Supabase, Stripe, OpenAI)

**Generic retry helper:**

```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  maxAttempts = 3,
  isRetryable = (error: any) => true,
): Promise<T> {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxAttempts - 1 || !isRetryable(error)) {
        throw error;
      }

      const delay = Math.pow(2, i) * 1000; // 1s, 2s, 4s
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  throw new Error("Retry logic failed to return");
}

test("uses retry for external API", async () => {
  const result = await withRetry(
    async () => {
      const response = await fetch("https://api.external.com/data");
      if (!response.ok) throw new Error("API error");
      return response.json();
    },
    3,
    (error) =>
      error.message.includes("rate limit") || error.message.includes("timeout"),
  );

  expect(result).toBeDefined();
});
```

---

## Pattern: hydration_wait

**When:** E2E tests with React hydration (MANDATORY for all E2E)

**Problem:** Playwright clicks pre-hydration → event handler not attached → no-op

**Solution Option 1: Hydration Marker**

```typescript
// In app/layout.tsx (one-time setup)
export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <script dangerouslySetInnerHTML={{
          __html: `document.body.dataset.hydrated = 'true';`
        }} />
      </body>
    </html>
  );
}

// In test
test("waits for hydration before interaction", async ({ page }) => {
  await page.goto("/form");
  await page.waitForSelector('body[data-hydrated="true"]');

  // Now safe to click
  await page.getByRole("button", { name: "Submit" }).click();
});
```

**Solution Option 2: Retry Until State Changes**

```typescript
test("retries click until state changes", async ({ page }) => {
  await page.goto("/form");

  // Click and verify state change (proves handler fired)
  await expect(async () => {
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page).toHaveURL(/\/success/);
  }).toPass({ timeout: 10000 });
});
```

**Reference:** `~/.claude/rules/playwright-patterns.md`

---

## Pattern: proper_timeouts

**When:** Any test involving external services

**Guideline:**

- Local operations: Default (5s)
- External API calls: 30s
- E2E navigation after form submit: 30s
- E2E hydration waits: 10s

```typescript
test("uses appropriate timeouts", async ({ page }) => {
  // E2E navigation after server action
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL(/\/success/, { timeout: 30000 }); // 30s for cold start

  // E2E hydration
  await expect(async () => {
    await page.getByRole("button", { name: "Next" }).click();
    await expect(page).toHaveURL(/\/step2/);
  }).toPass({ timeout: 10000 }); // 10s for hydration

  // Integration test with Supabase
  await expect(async () => {
    const { data } = await supabase.from("users").select().single();
    expect(data).toBeDefined();
  }).toPass({ timeout: 30000 }); // 30s for external service
});
```

**Why 30s for CI:**

- Cold Lambda starts: 5-10s
- Network latency: 2-5s
- Rate limiting delays: 1-4s
- Total: Can easily exceed 10s in CI

---

## Pattern: testing_server_actions_rule

**When:** Testing Next.js server actions

**Rule:** Never test server action directly. Extract and test business logic.

```typescript
// ❌ WRONG - Don't test this directly
"use server";
export async function addCategory(name: string) {
  await requireAdmin();
  const supabase = await createClient();
  // ... logic here
  revalidatePath("/categories");
}

// ✅ CORRECT - Extract logic
// actions.ts
("use server");
export async function addCategory(name: string) {
  await requireAdmin();
  const supabase = await createClient();
  const result = await addCategoryLogic(supabase, name); // Delegate
  if (result.success) revalidatePath("/categories");
  return result;
}

// logic.ts (testable)
export async function addCategoryLogic(supabase: SupabaseClient, name: string) {
  const { data, error } = await supabase
    .from("categories")
    .insert({ name })
    .select()
    .single();

  if (error) return { success: false, error };
  return { success: true, data };
}

// test (zero mocks)
import { addCategoryLogic } from "./logic";

test("adds category successfully", async ({ workerHousehold }) => {
  const supabase = createServiceRoleClient();

  const result = await addCategoryLogic(supabase, testName("Category"));

  expect(result.success).toBe(true);
  expect(result.data).toBeDefined();
});
```

**Why:**

- Server actions have 3 framework dependencies (cookies, auth, revalidate)
- Mocking framework internals is brittle and doesn't test real behavior
- Business logic extraction makes code testable AND more maintainable

**Reference:** `~/.claude/rules/testing-server-actions.md`

---

## Pattern: avoid_vi_clearAllMocks

**When:** Using module-level mocks

**Problem:** `vi.clearAllMocks()` in beforeEach breaks module-level mock implementations

```typescript
// ✅ CORRECT - Reset state, not implementation
let mockCallCount = 0;

vi.mock("@/lib/external-api", () => ({
  fetchData: vi.fn(() => {
    mockCallCount++;
    return { data: "value" };
  }),
}));

beforeEach(() => {
  mockCallCount = 0; // Reset state only
  // DO NOT use vi.clearAllMocks()
});

test("calls API", async () => {
  const result = await fetchData();
  expect(mockCallCount).toBe(1);
});
```

```typescript
// ❌ WRONG - Clears implementation
vi.mock("@/lib/external-api", () => ({ ... }));

beforeEach(() => {
  vi.clearAllMocks(); // Breaks module-level mocks!
});
```

**Reference:** `/docs/test-debugging-deep-dive.md` (Module-Scoped Mock State)

---

## Pattern Combination Examples

### Authentication Test (All Patterns)

```typescript
import { test, expect } from "@/tests/helpers/vitest-worker-fixture";
import { createServiceRoleClient } from "@/lib/supabase/server";
import { testName } from "@/tests/helpers/test-naming";

async function signInWithRetry(supabase, email, password, maxAttempts = 3) {
  // retry_logic pattern
  for (let i = 0; i < maxAttempts; i++) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (!error) return { data, error: null };
    if (error.message?.includes("rate limit")) {
      await new Promise((resolve) =>
        setTimeout(resolve, Math.pow(2, i) * 1000),
      );
      continue;
    }
    return { data: null, error };
  }
  throw new Error(`Failed after ${maxAttempts} attempts`);
}

test("handles concurrent login attempts", async ({ workerHousehold }) => {
  // worker_fixtures pattern
  const supabase = createServiceRoleClient();

  // Create additional user
  const email = `test-${crypto.randomUUID()}@example.com`;
  const password = crypto.randomUUID();

  const { data: userData, error: createError } =
    await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

  // error_checking pattern
  expect(createError).toBeNull();
  expect(userData.user).toBeDefined();

  // worker_fixtures_with_retry pattern
  const { data: session, error: signInError } = await signInWithRetry(
    supabase,
    email,
    password,
  );

  expect(signInError).toBeNull();
  expect(session.user).toBeDefined();
  expect(session.user.email).toBe(email);

  // Cleanup (worker fixture handles household cleanup)
  const { error: deleteError } = await supabase.auth.admin.deleteUser(
    userData.user.id,
  );
  expect(deleteError).toBeNull();
});
```

### E2E Test (Hydration + Timeout)

```typescript
import { test, expect } from "@/tests/e2e/fixtures/auth-fixture";

test("submits form with proper hydration and timeout", async ({
  page,
  workerAuth,
}) => {
  // Navigate and wait for hydration
  await page.goto("/create-meal");

  // hydration_wait pattern (Option 1)
  await page.waitForSelector('body[data-hydrated="true"]');

  // Fill form
  await page.fill('input[name="name"]', "Test Meal");

  // Submit with proper timeout
  await page.click('button[type="submit"]');

  // proper_timeouts pattern (30s for server action)
  await expect(page).toHaveURL(/\/meals\/[a-z0-9-]+/, { timeout: 30000 });

  // Verify success message (hydration_wait pattern Option 2)
  await expect(async () => {
    await expect(page.getByText("Meal created successfully")).toBeVisible();
  }).toPass({ timeout: 10000 });
});
```

---

## Pattern Selection Guide

| Scenario               | Patterns to Apply                           |
| ---------------------- | ------------------------------------------- |
| **Integration test**   | worker_fixtures + error_checking            |
| **Auth operations**    | worker_fixtures_with_retry + error_checking |
| **Delete operations**  | cascade_verification + error_checking       |
| **External API calls** | retry_logic + proper_timeouts               |
| **E2E tests**          | hydration_wait + proper_timeouts            |
| **Server actions**     | testing_server_actions_rule → extract logic |
| **Module-level mocks** | avoid_vi_clearAllMocks                      |

**Default:** worker_fixtures + error_checking (ALWAYS for integration tests)
