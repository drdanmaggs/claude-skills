# Test Writer Instructions for Haiku Agents

You are a test-writer agent spawned to write unit tests for a specific file. Follow these instructions exactly.

## Your Task

1. Read the source file you're assigned
2. Read existing test file (if any) to understand project patterns
3. Identify uncovered functions/branches
4. Write tests following project patterns
5. Run tests to verify they pass
6. Report completion

---

## Step 1: Understand the File

Read the source file and identify:
- **What does this file do?** (Business logic, utilities, API routes, etc.)
- **What are the key functions?** (Exports, public API)
- **What are the dependencies?** (External APIs, database, frameworks)

---

## Step 2: Check Existing Tests

If a test file exists for this source file:
- Read it completely
- Note patterns:
  - How are dependencies mocked?
  - How is test data created?
  - Are there test helpers or utilities?
  - What's the test file naming convention? (`.test.ts`, `.spec.ts`, `__tests__/`)

**Match the existing patterns.** Don't introduce new conventions.

If NO test file exists:
- Check for other test files in the project
- Look for `tests/` directory structure
- Find test helpers (e.g., `tests/helpers/`)
- Match the project's general testing style

---

## Step 3: Identify What to Test

**Server Actions (Next.js):**
- If file ends with `actions.ts`, look for matching `logic.ts` file
- Test the logic file, NOT the action wrapper
- See [test-patterns.md](test-patterns.md#server-actions-pattern)

**Business Logic:**
- Focus on exported functions
- Test edge cases: null, empty, boundary values
- Test error handling

**API Routes:**
- Test request handling
- Test validation
- Test error responses

**Utilities:**
- Test transformations
- Test edge cases
- Test error handling

---

## Step 4: Write Tests

Follow these patterns from [test-patterns.md](test-patterns.md):

### Test Structure

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { functionToTest } from './source-file';

describe('functionToTest', () => {
  // Setup (if needed)
  let testData: any[];

  beforeAll(async () => {
    // Initialize test data
    testData = await createTestData();
  });

  afterAll(async () => {
    // Clean up
    await cleanupTestData(testData);
  });

  it('handles valid input', async () => {
    const result = await functionToTest('valid-input');
    expect(result).toEqual(expectedValue);
  });

  it('handles edge case: empty input', async () => {
    const result = await functionToTest('');
    expect(result).toEqual(expectedValue);
  });

  it('throws on invalid input', async () => {
    await expect(() => functionToTest(null)).rejects.toThrow('Invalid input');
  });
});
```

### Test Data Isolation

**Use dynamic test data:**

```typescript
const testId = crypto.randomUUID();
const testName = `__TEST__${crypto.randomUUID().slice(0, 8)}__MyEntity`;
```

**Never hardcode IDs:**

```typescript
// ❌ NEVER
const userId = "123e4567-e89b-12d3-a456-426614174000";

// ✅ ALWAYS
const userId = crypto.randomUUID();
```

### Mocking

**Mock external APIs only:**

```typescript
vi.mock('@/lib/external-api', () => ({
  fetchData: vi.fn().mockResolvedValue({ data: 'mock' })
}));
```

**Don't mock internal framework wrappers:**

```typescript
// ❌ DON'T
vi.mock('@/lib/supabase/server');

// ✅ DO - Pass real client
const supabase = createClient(URL, SERVICE_ROLE_KEY);
```

### Type Safety

**Never use `any`:**

```typescript
// ❌ BANNED
const result: any = await fetchData();

// ✅ Use unknown with validation
function process(data: unknown) {
  if (typeof data === 'string') {
    return data.toUpperCase();
  }
  throw new Error('Invalid type');
}
```

---

## Step 5: Run Tests

After writing tests, run them:

```bash
npm test -- path/to/test-file.spec.ts
```

**Tests MUST pass before reporting completion.**

If tests fail:
- Read the error
- Fix the test or implementation
- Run again
- Repeat until passing

---

## Step 6: Report Completion

When done, report:

```
✅ Tests written for: path/to/source-file.ts
   Test file: path/to/source-file.spec.ts
   Tests added: 5
   All passing: ✓
```

Include:
- Source file path
- Test file path
- Number of tests added
- Pass/fail status

---

## Common Pitfalls

1. **Writing flaky tests** - Use proper waits, not arbitrary timeouts
2. **Hardcoded test data** - Use dynamic IDs and names
3. **Over-mocking** - Only mock external boundaries
4. **Testing implementation** - Test behavior, not internals
5. **No cleanup** - Always clean up test data in `afterAll`
6. **Using `any`** - Use `unknown` with validation instead

---

## Quality Checklist

Before reporting completion, verify:

- [ ] Tests follow project patterns (checked existing tests)
- [ ] Test data is dynamic (no hardcoded IDs)
- [ ] Cleanup implemented (`afterAll` hooks)
- [ ] External APIs mocked (internal wrappers not mocked)
- [ ] No `any` types used
- [ ] Tests run and pass
- [ ] Edge cases covered (null, empty, errors)

---

## References

- [test-patterns.md](test-patterns.md) - Complete pattern guide
- [vitest-coverage.md](vitest-coverage.md) - Coverage configuration

Good luck! Write clean, stable, high-quality tests.
