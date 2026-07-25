# Test Debugging Workflow

## Overview

Systematic approach to diagnosing and fixing failing tests.

## 1. Understand the Failure

### Read the Error Message
- **What failed?** - Assertion, timeout, exception, setup error?
- **Where?** - File path, line number, function/test name
- **Why?** - Expected vs actual values, error type

### Examine the Stack Trace
- Start from the bottom (root cause) not the top
- Identify the first line in YOUR code (skip framework internals)
- Note the sequence of calls leading to failure

### Categorize the Failure Type
- **Assertion failure** - Expected value doesn't match actual
- **Exception/error** - Code threw an error (null reference, type error, etc.)
- **Timeout** - Operation didn't complete in time
- **Setup/teardown failure** - Test environment issue
- **Missing dependency** - Mock, fixture, or resource not available

## 2. Reproduce Locally

### Run the Specific Test
```bash
# Vitest
npm test -- path/to/test.spec.ts -t "specific test name"

# Playwright
npx playwright test path/to/test.spec.ts:42
```

### Check Test Isolation
- Run test alone vs in suite
- Does it pass when run individually but fail in suite?
- Could indicate shared state or order dependency

### Verify Environment
- Are all dependencies installed?
- Is the database/API available?
- Are environment variables set?

## 3. Gather Context

### Read the Test Code
```javascript
test('creates user', async () => {
  const result = await createUser({ name: 'Test' });
  expect(result.id).toBeDefined(); // ← What's this checking?
  expect(result.name).toBe('Test'); // ← What's expected?
});
```

**Questions:**
- What is this test trying to verify?
- What are the test's assumptions?
- What setup does it require?

### Read the Implementation
```javascript
async function createUser(data) {
  const user = await db.insert(data);
  return user; // ← What does this return?
}
```

**Questions:**
- What does the code actually do?
- Does it match the test's expectations?
- Are there edge cases not handled?

### Check Recent Changes
```bash
git log --oneline -10
git diff HEAD~1 -- path/to/relevant/file.ts
```

**Questions:**
- Was the test or implementation recently changed?
- Did a dependency update break something?
- Was a feature removed but test not updated?

## 4. Form Hypothesis

Based on error + context, hypothesize the root cause:

**Example: "TypeError: Cannot read property 'id' of undefined"**
- Hypothesis: `createUser()` returns `undefined` instead of user object
- Why? Maybe database insert is failing silently
- Or: API endpoint changed response format

**Example: "Expected 'John' but received 'undefined'"**
- Hypothesis: User object missing `name` field
- Why? Maybe field name changed from `name` to `fullName`
- Or: Data not properly saved/retrieved

### Check Documentation if Framework-Related (NEW)

If error suggests framework-specific behavior, consult official docs:

**When to use Context7:**
- Error mentions framework API (e.g., "waitForSelector", "mockResolvedValue", "act warning")
- Behavior changed after framework upgrade
- Uncertain about expected framework behavior

**Example usage:**
```
Error: "strict mode violation" in Playwright test

Query Context7:
- Library: /microsoft/playwright
- Query: "strict mode selector expected behavior"
- Result: Use { name } option to disambiguate multiple elements

Hypothesis: Test needs more specific selector per framework best practices
```

See [context7-integration.md](context7-integration.md) for:
- When to consult documentation
- Common framework library IDs
- Query patterns and examples

## 5. Test Hypothesis

### Add Debug Logging
```javascript
test('creates user', async () => {
  const result = await createUser({ name: 'Test' });
  console.log('Result:', JSON.stringify(result, null, 2)); // ← Debug
  expect(result.id).toBeDefined();
});
```

### Use Debugger
```javascript
test('creates user', async () => {
  const result = await createUser({ name: 'Test' });
  debugger; // ← Pause here
  expect(result.id).toBeDefined();
});
```

Run with: `node --inspect-brk` or IDE debugger

### Simplify the Test
```javascript
// Remove everything except the failing line
test('creates user', async () => {
  const result = await createUser({ name: 'Test' });
  console.log('What is result?', result); // Start here
  // expect(result.id).toBeDefined(); // ← Comment out initially
});
```

## 6. Identify Root Cause

Common root causes:

### Test is Wrong
- **Incorrect assertion** - Test expects wrong value
- **Wrong test data** - Mock/fixture doesn't match reality
- **Stale test** - Code evolved but test didn't update
- **Wrong test location** - Testing implementation details not behavior

### Code is Wrong
- **Bug in implementation** - Logic error, missing null check
- **Unhandled edge case** - Code doesn't handle specific input
- **Incorrect return value** - Function returns wrong type/shape
- **Side effect not executed** - Database write, API call didn't happen

### Environment is Wrong
- **Missing setup** - Database not seeded, service not started
- **Incorrect configuration** - Wrong API URL, missing credentials
- **Dependency issue** - Package version mismatch, breaking change

## 7. Apply Fix

### If Test is Wrong

**Fix the assertion:**
```javascript
// ❌ Wrong
expect(user.name).toBe('John');

// ✅ Right (API actually returns fullName)
expect(user.fullName).toBe('John');
```

**Fix the test data:**
```javascript
// ❌ Wrong mock
mockApi.getUser.mockResolvedValue({ id: 1 });

// ✅ Right (include all required fields)
mockApi.getUser.mockResolvedValue({ id: 1, name: 'John', email: 'john@example.com' });
```

**Update stale test:**
```javascript
// ❌ Tests removed feature
test('shows legacy widget', () => {
  expect(screen.getByText('Legacy')).toBeInTheDocument();
});

// ✅ Remove or update test
// (Feature was intentionally removed)
```

### If Code is Wrong

**Fix the bug:**
```javascript
// ❌ Bug: doesn't handle null
function getUserName(user) {
  return user.name; // Crashes if user is null
}

// ✅ Fixed
function getUserName(user) {
  return user?.name ?? 'Unknown';
}
```

**Handle edge case:**
```javascript
// ❌ Doesn't handle empty array
function getFirstUser(users) {
  return users[0]; // Returns undefined if empty
}

// ✅ Fixed
function getFirstUser(users) {
  if (users.length === 0) {
    throw new Error('No users found');
  }
  return users[0];
}
```

### If Environment is Wrong

**Fix setup:**
```javascript
beforeAll(async () => {
  await startTestDatabase();
  await seedTestData(); // ← Was missing
});
```

**Fix configuration:**
```javascript
// ❌ Wrong
const API_URL = process.env.API_URL; // Undefined in tests

// ✅ Right
const API_URL = process.env.API_URL || 'http://localhost:3000';
```

## 8. Verify Fix

### Run the Failing Test
```bash
npm test -- path/to/test.spec.ts -t "specific test"
```

Passes? Good! Now verify you didn't break anything else.

### Run Related Tests
```bash
# Run all tests in same file
npm test -- path/to/test.spec.ts

# Run all tests in same directory
npm test -- path/to/tests/
```

All pass? Great! Now run the full suite.

### Run Full Test Suite
```bash
npm test
```

If other tests now fail, your fix may have unintended side effects.

## 9. Prevent Regression

### Add Regression Test
If the bug was in code, add a test for the edge case:

```javascript
test('getUserName handles null user', () => {
  expect(getUserName(null)).toBe('Unknown');
});

test('getFirstUser throws on empty array', () => {
  expect(() => getFirstUser([])).toThrow('No users found');
});
```

### Improve Error Messages
```javascript
// ❌ Unclear error
expect(result).toBeDefined();

// ✅ Clear error
expect(result).toBeDefined(); // createUser should return user object
```

Or use better assertions:
```javascript
// ❌ Generic
expect(user.name).toBe('John');

// ✅ Specific
expect(user).toMatchObject({
  name: 'John',
  email: expect.stringContaining('@')
});
```

## Troubleshooting Checklist

When stuck, check:
- [ ] Did I read the FULL error message?
- [ ] Did I check the stack trace?
- [ ] Can I reproduce it locally?
- [ ] Did I read both test AND implementation?
- [ ] Did I check recent git changes?
- [ ] Did I add debug logging?
- [ ] Did I try simplifying the test?
- [ ] Am I testing the right thing?
- [ ] Are my mocks/fixtures correct?
- [ ] Is the test environment set up correctly?

## Common Pitfalls

**Fixing symptoms, not root cause:**
- Don't just make the test pass by changing assertions
- Understand WHY it was failing

**Not verifying the fix:**
- Don't assume it works - run the tests
- Check for side effects on other tests

**Leaving debug code:**
- Remove `console.log`, `debugger` statements
- Clean up temporary changes

**Not adding regression tests:**
- If you found a bug, prevent it from coming back
- Add a test that would have caught it
