# Mandatory Test Patterns

**Purpose:** Enforce production-ready patterns from test-fixer learnings

**Applies to:** All generated tests (validation in Phase 1.4)

---

## 1. Worker-Scoped Fixtures (MANDATORY)

### Integration Tests

```typescript
// ✅ CORRECT
import { test, expect } from "@/tests/helpers/vitest-worker-fixture";

test("creates user data", async ({ workerHousehold }) => {
  // workerHousehold provides: householdId, userId, authUserId, etc.
  const { data, error } = await supabase
    .from("meals")
    .insert({ household_id: workerHousehold.householdId })
    .select()
    .single();

  expect(error).toBeNull();
  expect(data).toBeDefined();
});
```

```typescript
// ❌ WRONG - Manual cleanup (doesn't run on crash/timeout)
import { test, expect, beforeAll, afterAll } from "vitest";

let household: IsolatedTestHousehold;

beforeAll(async () => {
  const supabase = createServiceRoleClient();
  household = await createIsolatedTestHousehold(supabase);
});

afterAll(async () => {
  // This NEVER runs if test crashes or is interrupted!
  await cleanupIsolatedTestHousehold(supabase, household);
});
```

**Why mandatory:**

- Cleanup runs even on crash/timeout/Ctrl+C
- Parallel execution completely safe (each worker isolated)
- Simpler code (no manual beforeAll/afterAll)

**Reference:** `~/.claude/rules/testing.md` (Data Management section)

### E2E Tests

```typescript
// ✅ CORRECT
import { test, expect } from "@/tests/e2e/fixtures/auth-fixture";

test("user flow", async ({ page, workerAuth }) => {
  // workerAuth provides: email, password, userId, householdId
  await page.goto("/dashboard");
  expect(page.url()).toContain("/dashboard");
});
```

**Reference:** `~/.claude/rules/test-user-isolation.md`

---

## 2. Unique IDs Everywhere (MANDATORY)

```typescript
// ✅ CORRECT - Dynamic IDs
import { testName } from "@/tests/helpers/test-naming";

test("creates category", async ({ workerHousehold }) => {
  const categoryName = testName("Category"); // "__TEST__abc12345__Category"
  const categoryId = crypto.randomUUID();

  const { data, error } = await supabase
    .from("categories")
    .insert({
      id: categoryId,
      name: categoryName,
      household_id: workerHousehold.householdId,
    })
    .select()
    .single();

  expect(error).toBeNull();
});
```

```typescript
// ❌ WRONG - Hardcoded IDs
const TEST_USER_ID = "hardcoded-uuid";
const TEST_HOUSEHOLD_ID = "another-hardcoded-uuid";

await supabase.from("meals").insert({
  household_id: TEST_HOUSEHOLD_ID, // BRITTLE!
});
```

**Why mandatory:**

- Parallel execution safe (no ID collisions)
- Tests are self-sufficient (no setup dependencies)
- Easy cleanup (testName prefix pattern)

**Reference:** `~/.claude/rules/test-user-isolation.md`

---

## 3. Error Checking on ALL DB Operations (MANDATORY)

```typescript
// ✅ CORRECT - Check error on every operation
const { data, error } = await supabase
  .from("categories")
  .insert({ name: testName("Category") })
  .select()
  .single();

expect(error).toBeNull(); // CRITICAL - catches silent failures
expect(data).toBeDefined();
expect(data.name).toContain("Category");
```

```typescript
// ❌ WRONG - Unchecked operation (silent failures)
const { data } = await supabase
  .from("categories")
  .insert({ name: testName("Category") })
  .select()
  .single();

// If RLS denies this, data is null but test continues!
expect(data.name).toContain("Category"); // TypeError: Cannot read properties of null
```

**Why mandatory:**

- Supabase returns `{ data: null, error }` instead of throwing
- RLS policy violations are silent without error checking
- Tests fail fast with clear error messages

**Common DB operations to check:**

- `.insert()` - RLS, FK violations
- `.update()` - RLS, row not found
- `.delete()` - RLS, CASCADE issues
- `.select()` - RLS, missing data
- `.upsert()` - Conflict handling

---

## 4. Proper Timeouts for External Services (MANDATORY)

```typescript
// ✅ CORRECT - 30s timeout for external services
await expect(page).toHaveURL(/\/success/, { timeout: 30000 });

await expect(async () => {
  const { data } = await supabase.from("users").select().single();
  expect(data).toBeDefined();
}).toPass({ timeout: 30000 });
```

```typescript
// ❌ WRONG - Tight timeout (fails in CI)
await expect(page).toHaveURL(/\/success/, { timeout: 5000 }); // Too tight!
```

**Why mandatory:**

- CI cold starts take longer (Lambda, Edge Functions)
- Network latency varies (inter-region calls)
- Supabase rate limiting may delay responses

**Timeout guidelines:**

- Local operations: Default (5s)
- External API calls: 30s
- E2E navigation after form submit: 30s
- E2E hydration waits: 10s

**Reference:** `~/.claude/rules/playwright-patterns.md`

---

## 5. Avoid Known Flaky Patterns (MANDATORY)

### Pattern 5a: No vi.clearAllMocks() with Module-Level Mocks

```typescript
// ✅ CORRECT - Reset state, not mock implementation
let mockState = { callCount: 0 };

vi.mock("some-module", () => ({
  someFunction: vi.fn(() => {
    mockState.callCount++;
    return { data: "value" };
  }),
}));

beforeEach(() => {
  mockState.callCount = 0; // Reset state only
  // No vi.clearAllMocks()!
});
```

```typescript
// ❌ WRONG - Clears mock implementation
vi.mock("some-module", () => ({ ... }));

beforeEach(() => {
  vi.clearAllMocks(); // Breaks module-level mocks!
});
```

**Reference:** `/docs/test-debugging-deep-dive.md` (Module-Scoped Mock State Interference)

### Pattern 5b: Wait for React Hydration (E2E)

```typescript
// ✅ CORRECT - Wait for hydration before interaction
test("submit form", async ({ page }) => {
  await page.goto("/form");

  // Option 1: Hydration marker
  await page.waitForSelector('body[data-hydrated="true"]');

  // Option 2: Retry until state changes
  await expect(async () => {
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page).toHaveURL(/\/success/);
  }).toPass({ timeout: 10000 });

  // Now click is safe
  await page.getByRole("button", { name: "Submit" }).click();
});
```

```typescript
// ❌ WRONG - Click before hydration
test("submit form", async ({ page }) => {
  await page.goto("/form");
  await page.getByRole("button", { name: "Submit" }).click(); // Pre-hydration click = no-op!
});
```

**Reference:** `~/.claude/rules/playwright-patterns.md`

### Pattern 5c: Retry Logic for Supabase Rate Limiting

```typescript
// ✅ CORRECT - Exponential backoff retry
async function signInWithRetry(supabase, email, password, maxAttempts = 3) {
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
```

**Reference:** `/docs/test-debugging-deep-dive.md` (Supabase Auth Rate Limiting at Scale)

---

## 6. Avoid CASCADE DELETE Race Conditions (MANDATORY)

```typescript
// ✅ CORRECT - Manual child-first deletion
afterAll(async () => {
  if (!context) return;

  // Delete children FIRST (reverse FK order)
  await supabase.from("meals").delete().eq("household_id", householdId);
  await supabase.from("categories").delete().eq("household_id", householdId);

  // Then delete parent
  await supabase.from("households").delete().eq("id", householdId);
});
```

```typescript
// ❌ WRONG - Rely on CASCADE DELETE (race condition risk)
afterAll(async () => {
  // CASCADE automatically deletes children...
  // But what if another worker's test is using those children?
  await supabase.from("households").delete().eq("id", householdId);
});
```

**Why mandatory:**

- Worker A's CASCADE can delete Worker B's data mid-test
- Causes "Cannot read properties of null" errors
- Only happens in parallel execution (CI catches, local doesn't)

**Detection:**

```bash
# Check schema for CASCADE constraints
grep -r "ON DELETE CASCADE" supabase/migrations/
```

**Reference:** `~/.claude/rules/self-cleaning-tests.md`

---

## 7. Prefer Worker Fixtures Over describe.sequential (MANDATORY)

```typescript
// ✅ CORRECT - Worker fixtures (parallel-safe)
import { test, expect } from "@/tests/helpers/vitest-worker-fixture";

test("test 1", async ({ workerHousehold }) => { ... });
test("test 2", async ({ workerHousehold }) => { ... });
// Both tests run in parallel, each with isolated data
```

```typescript
// ⚠️ RARE EXCEPTION - Only for state machines
describe.sequential("State Machine Tests", () => {
  // ⚠️ REQUIRED: Comment explaining why these tests can't be parallel
  // Example: "Testing state transitions that depend on execution order"

  let household: IsolatedTestHousehold;

  beforeAll(async () => {
    household = await createIsolatedTestHousehold(supabase);
  });

  afterAll(async () => {
    await cleanupIsolatedTestHousehold(supabase, household);
  });

  it("step 1", async () => { ... });
  it("step 2", async () => { ... }); // Depends on step 1 state
});
```

**Reference:** `~/.claude/rules/testing.md` (Data Management section)

---

## Validation Checklist

**Phase 1.4 automated checks:**

```typescript
const validations = [
  {
    check: () => fileContains("workerHousehold") || fileContains("workerAuth"),
    severity: "ERROR",
    message: "Missing worker-scoped fixture import",
  },
  {
    check: () =>
      !fileContains("TEST_USER_ID") && !fileContains("TEST_HOUSEHOLD_ID"),
    severity: "ERROR",
    message: "Hardcoded test ID found (violates isolation)",
  },
  {
    check: () => {
      const insertCount = countMatches(/\.insert\(/g);
      const updateCount = countMatches(/\.update\(/g);
      const deleteCount = countMatches(/\.delete\(/g);
      const totalOps = insertCount + updateCount + deleteCount;

      const errorChecks = countMatches(/expect\(error\)/g);
      return errorChecks >= totalOps;
    },
    severity: "ERROR",
    message: "Unchecked DB operations (missing error assertions)",
  },
  {
    check: () => {
      const shortTimeouts = countMatches(/timeout:\s*[1-9]\d{3}(?![0-9])/g); // 1000-9999ms
      return shortTimeouts === 0;
    },
    severity: "WARNING",
    message: "Timeout <10s found (may fail in CI)",
  },
  {
    check: () => {
      const hasManualCleanup =
        fileContains("afterAll") || fileContains("afterEach");
      const hasSequential = fileContains("describe.sequential");
      if (hasManualCleanup && !hasSequential) return false;
      return true;
    },
    severity: "ERROR",
    message: "Manual cleanup without describe.sequential (use worker fixtures)",
  },
  {
    check: () => !fileContains("vi.clearAllMocks"),
    severity: "WARNING",
    message: "vi.clearAllMocks() found (breaks module-level mocks)",
  },
  {
    check: () => {
      const hasGoto = fileContains("page.goto");
      const hasClick = fileContains(".click()");
      const hasHydrationWait =
        fileContains("waitForSelector") || fileContains("toPass({");

      if (hasGoto && hasClick && !hasHydrationWait) return false;
      return true;
    },
    severity: "WARNING",
    message: "E2E test clicks without hydration wait",
  },
];
```

---

## When Patterns Can Be Skipped

**Worker fixtures:** NEVER skip for integration/E2E tests

**Error checking:** NEVER skip for DB operations

**Timeouts:** Can use default for pure unit tests (no I/O)

**Unique IDs:** Can skip for pure unit tests (no DB)

**Hydration waits:** Only applies to E2E tests

**CASCADE checks:** Only if schema has no CASCADE DELETE

**describe.sequential:** Only use with justification comment
