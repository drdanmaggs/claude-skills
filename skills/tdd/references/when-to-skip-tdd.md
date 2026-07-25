# When NOT to Use TDD

Some work triggers TDD auto-detect keywords but doesn't benefit from test-first development. **Skip TDD and code directly** for these exceptions.

## The Four Exceptions

| Exception | Why | What to do instead |
|-----------|-----|---------------------|
| **UI styling/layout** | Can't write a failing test for "this looks right." Spacing, colour, visual hierarchy are human judgment. | Build it, eyeball in browser, iterate. Test that components render and elements exist — not aesthetics. |
| **Exploratory spikes** | You don't know the API shape yet. Tests lock you into a design you haven't discovered. | Spike it, throw it away, then TDD the real implementation. |
| **Static content/copy** | Changing "Submit" to "Save Changes" has no logic to test. Pure ceremony. | Just change the text. |
| **One-off scripts/migrations** | Database migrations, data backfills, cleanup scripts run once. | `db push --dry-run` is the safety net. Verify output manually. |

## Decision Framework

**Ask yourself:**
1. Does this change have testable logic?
2. Will this code run more than once?
3. Could this break in unexpected ways?

**If NO to all three** → Skip TDD, code directly.
**If YES to any** → Use TDD.

## Examples

### ✅ Skip TDD (Good Call)

**UI Styling:**
```typescript
// Just do it — no test can validate "looks right"
<Button className="px-4 py-2 rounded-lg bg-blue-500">
  Submit
</Button>
```

**Static Copy:**
```typescript
// No logic to test
<h1>Welcome to Our App</h1>
```

**One-off Migration:**
```sql
-- Run once with --dry-run, verify output
UPDATE households SET timezone = 'UTC' WHERE timezone IS NULL;
```

### ❌ Don't Skip TDD (Needs Tests)

**Button with Logic:**
```typescript
// Has validation logic — NEEDS test
function handleSubmit() {
  if (!form.isValid()) return; // Logic!
  await api.save(form.data);    // Side effect!
}
```

**Dynamic Content:**
```typescript
// Behavior depends on state — NEEDS test
<h1>{user ? `Welcome ${user.name}` : 'Please log in'}</h1>
```

**Reusable Script:**
```typescript
// Will be run multiple times — NEEDS test
export function backfillCategories(households: Household[]) {
  // This is logic, not a one-off
}
```

## Gray Areas

**Component renders but behavior is untested:**
- Test: Component renders without crashing ✅
- Test: Specific spacing or color ❌
- Test: Click handler fires ✅
- Test: Visual alignment of elements ❌

**Configuration files:**
- Simple config object (JSON, env vars): No test needed
- Complex config with derived values: TDD it

**Database schema changes:**
- Migration file DDL: No test (use `--dry-run`)
- RLS policies: **TDD them** (business logic!)
- Triggers/functions: **TDD them** (behavior!)

## The Rule of Thumb

**If in doubt, ask the user.**

These exceptions don't excuse skipping tests for:
- Logic
- Validation
- Behavior
- Stateful operations
- User-facing functionality

Only skip when tests add **ceremony without catching real bugs**.
