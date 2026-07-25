# Test Standards

**How this file is used:** The tdd-test-writer subagent reads this file directly during the RED phase. The orchestrator tells it which test type section to read (e.g., "read the Integration Tests section"). Subagents: read the **Universal** section plus the section matching your test type.

---

## Universal (All Test Types)

### Data Isolation
- Tests create their own data — never depend on pre-existing DB state
- Use unique IDs (e.g., `crypto.randomUUID()`) for test entities
- Never hardcode user IDs, household IDs, or any shared identifiers
- Each test suite should be runnable on a completely empty database

### Cleanup
- Track all created entity IDs in arrays/variables
- Clean up in `afterAll` / `afterEach` — delete children before parents (respect FK constraints)
- Search the project for existing cleanup helpers before writing your own

### Test Independence
- No shared mutable state between tests
- Each test must pass in isolation and in any order
- Use `beforeEach` for per-test setup, `beforeAll` for expensive one-time setup

### Test Naming

**Describe behavior, not implementation.** A good test name answers three questions:
1. **What** is being tested?
2. **Under what conditions?**
3. **What should happen?**

**When a test fails in CI, the name should be the bug report.**

#### Naming Heuristics

Use these patterns to transform plan items into proper test names:

**Positive cases:**
```typescript
should [action] when [condition]
should return [result] for [input]
should [behavior] given [precondition]
```

**Negative/validation cases:**
```typescript
should reject [input] when [invalid condition]
should return [error] when [missing requirement]
should throw error when [failure scenario]
```

**Edge cases:**
```typescript
should handle empty [collection]
should handle null/undefined [input]
should handle [boundary condition]
```

**State changes:**
```typescript
should create [resource] with [properties]
should update [entity] when [action occurs]
should delete [resource] and cascade to [related]
```

**Permission/RLS:**
```typescript
should allow [role] to [action] their own [resource]
should prevent [role] from accessing [other user's resource]
should return 403 when user lacks [permission]
```

#### Examples: Bad → Good

| ❌ Bad | ✅ Good | Why |
|--------|---------|-----|
| `test addCategory` | `should create category with unique name` | Describes behavior, not function name |
| `should work when valid` | `should return 201 when name is valid` | Specific outcome + condition |
| `test error handling` | `should return 400 when name is empty` | Precise error case |
| `should correctly validate` | `should reject names longer than 100 chars` | No "correctly", specific boundary |
| `testGetByHousehold` | `should return only user's own categories` | Behavior over implementation |
| `should handle edge case` | `should return empty array when no matches` | Explicit edge case |
| `it works` | `should save recipe to database` | Specific action |
| `should do X properly` | `should trim whitespace from input` | Concrete behavior |

#### Context from describe() Blocks

The `describe` provides context, so `it()` can be terser:

```typescript
// ✅ Good - describe provides context
describe('addCategory', () => {
  it('should create category with unique name', ...)
  it('should reject empty name', ...)
  it('should reject duplicate name in same household', ...)
})
// Reads: "addCategory should reject empty name"

// ❌ Redundant - repeating "addCategory" in every test
describe('addCategory', () => {
  it('addCategory should create category', ...)  // Redundant!
})
```

#### Transforming Plan Items

When converting plan items to test names, be specific:

| Plan Item | Test Name |
|-----------|-----------|
| "creates record and returns ID" | `should create category and return its ID` |
| "rejects empty name" | `should reject empty name` |
| "enforces RLS" | `should return only categories from user's household` |
| "handles empty results" | `should return empty array when no categories match filter` |
| "validates length" | `should reject names longer than 100 characters` |
| "trims whitespace" | `should trim leading and trailing whitespace from name` |

**Rules:**
- Start `it()` with `should` — forces behavioral description
- Never reference function names — `should calculate total with discount` survives a refactor, `test applyDiscount returns correct value` breaks when you rename
- Avoid `correctly` / `properly` / `works` — they tell you nothing
- Be specific about outcomes — not "handles errors" but "returns 400 when name is empty"
- CI benefit: when a build fails, the test name IS the bug report

### Assertions
- Test behavior, not implementation details
- One logical assertion per test (multiple `expect` calls are fine if they test the same behavior)

### Code Quality
- No `any` types — use proper typing or `unknown` with validation
- No `@ts-ignore` or `@ts-expect-error` unless absolutely necessary with a comment explaining why

### Discovery First
- Before writing any test, search for existing test helpers, fixtures, and patterns in the project
- Read 1-2 existing test files of the same type to learn conventions
- Use whatever helpers the project already provides — don't reinvent

---

## Unit Tests (Vitest)

### Structure
- Colocate with source: `feature.test.ts` next to `feature.ts`, or in `__tests__/` directory — match project convention
- Use `describe` blocks to group related tests
- AAA pattern: Arrange (setup), Act (call function), Assert (check result)

### Mocking
- Mock external boundaries only (APIs, databases, third-party services)
- Never mock the module under test
- Use `vi.mock()` for module-level mocks, `vi.fn()` for function mocks
- Reset mocks between tests: `vi.restoreAllMocks()` in `afterEach`
- When mocking returns values, match the real API shape exactly

### Async
- Always `await` async operations — missing `await` is the #1 cause of flaky unit tests
- Mark test functions `async` when they contain `await`
- Use `vi.useFakeTimers()` for timer-dependent code, restore with `vi.useRealTimers()`

### Flexible Assertions
- `toBeCloseTo()` for floating-point comparisons
- `expect.arrayContaining()` when order doesn't matter
- `expect.objectContaining()` for partial object matching
- `toMatchObject()` for nested partial matching
- `expect.any(String)` for dynamic values like IDs and timestamps

### Anti-pattern: Removal-without-preservation testing

When a form removes a field, test both sides:

❌ Incomplete — tests UI but not data contract:
```typescript
it("does not render Notes field", () => {
  expect(screen.queryByLabelText(/notes/i)).not.toBeInTheDocument();
});
```

✅ Complete — tests UI AND data contract:
```typescript
it("does not render Notes field", () => {
  expect(screen.queryByLabelText(/notes/i)).not.toBeInTheDocument();
});

it("preserves existing notes in submit payload", async () => {
  const memberWithNotes = { ...member, preferences: { ...prefs, notes: "existing" } };
  render(<Form member={memberWithNotes} />);
  await user.click(screen.getByRole("button", { name: /save/i }));
  expect(mockAction.mock.calls[0][0].preferences.notes).toBe("existing");
});
```

**Trigger:** Any plan slice containing "preserve", "maintain", "keep", "not lose", or
"still include" requires a submit payload assertion, not just a DOM assertion.

**Why:** Full JSONB/object replacement actions silently delete omitted fields. Testing DOM
absence only verifies the UI — it cannot catch data-loss bugs.

See also: `~/.claude/rules/form-field-removal-testing.md`

### Anti-Patterns to Avoid
- Hard waits (`setTimeout` / `new Promise(resolve => setTimeout(...))`)
- Shared mutable state between tests (global `let` mutated by multiple tests)
- Testing private/internal methods — test the public API
- Mocking everything — if you mock the thing you're testing, you're testing the mock
- Overly strict assertions on timestamps, UUIDs, or floating-point values

---

## Integration Tests (Vitest + Real Database)

### Architecture
- Test logic functions, not server action wrappers — logic functions accept dependencies (like a Supabase client) as parameters
- Pass a real Supabase client (service role) — don't mock the database
- The server action wrapper handles auth + revalidation; test those via E2E

### Data Setup
- Search for the project's test data helper (often in `tests/helpers/`)
- Create isolated test data per suite: unique auth user + related entities
- Use unique emails: `test-${crypto.randomUUID()}@example.com`
- Return all created IDs for cleanup

### Cleanup Order (Critical)
- Delete in reverse FK order: children before parents
- Know which FKs are CASCADE (auto-delete) vs RESTRICT (manual delete required)
- If the project has a cleanup helper, use it — don't write cleanup from scratch

### What to Mock vs What to Hit
- **Hit real:** Database operations, RLS policies, data validation
- **Mock:** External APIs (AI services, payment providers, email), `revalidatePath`, auth checks

---

## E2E Tests (Playwright)

### Locator Strategy (Priority Order)
1. **Role-based:** `page.getByRole('button', { name: 'Submit' })` — best, accessibility-aligned
2. **Label-based:** `page.getByLabel('Email')` — good for form fields
3. **Text-based:** `page.getByText('Welcome')` — for visible text
4. **Test ID:** `page.getByTestId('checkout')` — when semantic locators aren't possible
5. **Never:** CSS classes, XPath, DOM structure selectors — brittle

### Waiting
- Trust Playwright's auto-waiting — don't add manual waits
- Use `await expect(locator).toBeVisible()` for assertions that auto-retry
- For dynamic content: `page.waitForSelector('[data-loaded="true"]')`
- Never use `page.waitForTimeout()` — always wait for a specific condition

### Test Isolation
- Each test gets its own browser context/page
- Auth state: use Playwright's `storageState` for login, don't log in per test
- Search for the project's auth setup (often `auth.setup.ts`)

### Assertions
- Use web-first assertions: `await expect(page.getByText('Success')).toBeVisible()`
- These auto-retry until timeout — no need for manual polling
- For navigation: `await expect(page).toHaveURL('/dashboard')`

### Debugging Config
- Traces on first retry: `trace: 'on-first-retry'`
- Screenshots on failure: `screenshot: 'only-on-failure'`
- View traces: `npx playwright show-trace path/to/trace.zip`

### Anti-Patterns to Avoid
- `page.waitForTimeout()` — always flaky
- CSS class selectors (`'.btn-primary'`) — break with styling changes
- Hardcoded ports — use dynamic port capture if the project supports it
- Testing implementation details through the UI — test user-visible behavior

---

## pgTAP Tests (Database)

### Structure
- Tests live in `supabase/tests/database/` as `.sql` files
- Run with `supabase test db`
- Test RLS policies, triggers, functions, constraints

### RLS Testing Pattern
- Create test users with specific roles
- Authenticate as each role using `set_config('request.jwt.claims', ...)`
- Verify: can access own data, cannot access other users' data
- Test both SELECT and INSERT/UPDATE/DELETE policies

### What to Test
- Row Level Security policies (critical for multi-tenant apps)
- Database functions and triggers
- Constraint violations (unique, check, FK)
- Edge cases in SQL logic
