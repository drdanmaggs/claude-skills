# Common Test Failure Patterns

## Table of Contents
1. [Assertion Failures](#assertion-failures)
2. [Null/Undefined Errors](#nullundefined-errors)
3. [Type Errors](#type-errors)
4. [Timeout Failures](#timeout-failures)
5. [Setup/Teardown Issues](#setupteardown-issues)
6. [Mock/Stub Problems](#mockstub-problems)
7. [Async/Promise Issues](#asyncpromise-issues)
8. [DOM/Element Not Found](#domelement-not-found)
9. [Data Issues](#data-issues)
10. [Environment Issues](#environment-issues)

---

## Assertion Failures

### Pattern: Expected vs Actual Mismatch

**Error:**
```
Expected: 'John Doe'
Received: 'John'
```

**Common Causes:**
1. API response format changed
2. Code logic error
3. Test expectation is wrong
4. Data transformation issue

**Debug:**
```javascript
test('returns full name', () => {
  const result = getFullName({ first: 'John', last: 'Doe' });
  console.log('Result:', result); // Check actual output
  expect(result).toBe('John Doe');
});
```

**Fixes:**

If code is wrong:
```javascript
// ❌ Bug
function getFullName(user) {
  return user.first; // Missing last name
}

// ✅ Fixed
function getFullName(user) {
  return `${user.first} ${user.last}`;
}
```

If test is wrong:
```javascript
// ❌ Wrong expectation
expect(result).toBe('John Doe'); // API only returns first name

// ✅ Fixed expectation
expect(result).toBe('John');
```

### Pattern: Array/Object Mismatch

**Error:**
```
Expected: [1, 2, 3]
Received: [1, 2, 3, 4]
```

**Common Causes:**
1. Extra items added (feature change)
2. Missing filter/slice
3. Test data changed

**Fix:**
```javascript
// ❌ Too strict
expect(items).toEqual([1, 2, 3]);

// ✅ More flexible
expect(items).toEqual(expect.arrayContaining([1, 2, 3]));
// or
expect(items).toHaveLength(3);
```

---

## Null/Undefined Errors

### Pattern: Cannot Read Property of Undefined

**Error:**
```
TypeError: Cannot read property 'name' of undefined
```

**Common Causes:**
1. Function returns `undefined`
2. Object property doesn't exist
3. Async data not loaded yet
4. Mock not set up correctly

**Debug:**
```javascript
test('gets user name', async () => {
  const user = await getUser('123');
  console.log('User object:', user); // ← Check what you got
  expect(user.name).toBe('John');
});
```

**Fixes:**

If code is wrong:
```javascript
// ❌ Doesn't return value
async function getUser(id) {
  const user = await db.findById(id);
  // Missing return!
}

// ✅ Fixed
async function getUser(id) {
  const user = await db.findById(id);
  return user;
}
```

If test needs null handling:
```javascript
// ❌ Assumes user exists
expect(user.name).toBe('John');

// ✅ Check for null first
expect(user).toBeDefined();
expect(user?.name).toBe('John');
```

### Pattern: Undefined Variable

**Error:**
```
ReferenceError: userId is not defined
```

**Common Causes:**
1. Typo in variable name
2. Variable not in scope
3. Import missing

**Fix:**
```javascript
// ❌ Wrong variable name
expect(userid).toBe('123'); // Typo: should be userId

// ✅ Fixed
expect(userId).toBe('123');
```

---

## Type Errors

### Pattern: X is not a function

**Error:**
```
TypeError: mockFn is not a function
```

**Common Causes:**
1. Mock not properly set up
2. Import error (got object instead of function)
3. Dependency not injected

**Fix:**
```javascript
// ❌ Wrong mock setup
const mockFn = { mockResolvedValue: jest.fn() }; // This isn't a function

// ✅ Fixed
const mockFn = jest.fn().mockResolvedValue({ id: '123' });
```

### Pattern: X is not iterable

**Error:**
```
TypeError: items is not iterable
```

**Common Causes:**
1. Expected array, got object or null
2. API response format changed

**Fix:**
```javascript
// ❌ Assumes API returns array
const items = await getItems();
for (const item of items) { ... }

// ✅ Defensive
const items = await getItems();
const itemArray = Array.isArray(items) ? items : [];
for (const item of itemArray) { ... }
```

---

## Timeout Failures

### Pattern: Test Exceeded Timeout

**Error:**
```
Test timeout of 5000ms exceeded
```

**Common Causes:**
1. Async operation never completes
2. Missing await
3. Infinite loop
4. External service slow/down

**Debug:**
```javascript
test('loads data', async () => {
  console.log('Starting test');
  const data = await loadData();
  console.log('Data loaded'); // ← Does this print?
  expect(data).toBeDefined();
});
```

**Fixes:**

If missing await:
```javascript
// ❌ Missing await
test('saves user', () => {
  saveUser({ name: 'John' }); // Promise never awaited
  expect(user).toBeDefined();
});

// ✅ Fixed
test('saves user', async () => {
  await saveUser({ name: 'John' });
  expect(user).toBeDefined();
});
```

If operation genuinely slow:
```javascript
// ✅ Increase timeout for specific test
test('slow operation', async () => {
  test.setTimeout(30000); // 30 seconds
  await slowOperation();
}, 30000);
```

If external dependency:
```javascript
// ✅ Mock it
vi.mock('./api', () => ({
  fetchData: vi.fn().mockResolvedValue({ data: 'test' })
}));
```

---

## Setup/Teardown Issues

### Pattern: Database/State Pollution

**Error:**
```
Expected 1 user, found 3 users
```

**Common Causes:**
1. Previous test left data
2. Missing cleanup
3. Tests not isolated

**Fix:**
```javascript
// ❌ No cleanup
test('creates user', async () => {
  await createUser({ name: 'John' });
  const users = await getUsers();
  expect(users).toHaveLength(1);
});

// ✅ Proper cleanup
let testUserId;

afterEach(async () => {
  if (testUserId) {
    await deleteUser(testUserId);
  }
});

test('creates user', async () => {
  const user = await createUser({ name: 'John' });
  testUserId = user.id;
  const users = await getUsers();
  expect(users).toHaveLength(1);
});
```

Better: Use transactions
```javascript
beforeEach(async () => {
  await db.beginTransaction();
});

afterEach(async () => {
  await db.rollback();
});
```

---

## Mock/Stub Problems

### Pattern: Mock Not Called

**Error:**
```
Expected mock to be called, but it wasn't
```

**Common Causes:**
1. Code uses different instance
2. Mock set up after code runs
3. Import mocked incorrectly

**Debug:**
```javascript
test('calls API', async () => {
  const mockFetch = vi.fn();
  // Is this the same fetch the code uses?
  await myFunction();
  expect(mockFetch).toHaveBeenCalled();
});
```

**Fix:**
```javascript
// ❌ Mock set up wrong
import { fetchUser } from './api';
const mockFetch = vi.fn();

test('calls API', async () => {
  await loadUser(); // Uses real fetchUser, not mock
});

// ✅ Properly mocked
vi.mock('./api', () => ({
  fetchUser: vi.fn().mockResolvedValue({ id: '123' })
}));

test('calls API', async () => {
  await loadUser();
  expect(fetchUser).toHaveBeenCalled();
});
```

### Pattern: Mock Returns Undefined

**Error:**
```
Expected object, received undefined
```

**Common Causes:**
1. Mock not configured to return value
2. Wrong mock method used

**Fix:**
```javascript
// ❌ Mock doesn't return value
const mockFetch = vi.fn();

// ✅ Mock returns value
const mockFetch = vi.fn().mockResolvedValue({ data: 'test' });
// or for sync
const mockFetch = vi.fn().mockReturnValue({ data: 'test' });
```

---

## Async/Promise Issues

### Pattern: Promise Not Awaited

**Error:**
```
Received: Promise { <pending> }
```

**Common Causes:**
1. Missing await keyword
2. Test not marked async
3. Not returning promise

**Fix:**
```javascript
// ❌ Missing await
test('loads data', () => {
  const data = loadData(); // Returns promise
  expect(data).toBeDefined(); // Checks promise, not data
});

// ✅ Fixed with await
test('loads data', async () => {
  const data = await loadData();
  expect(data).toBeDefined();
});

// ✅ Or return promise
test('loads data', () => {
  return loadData().then(data => {
    expect(data).toBeDefined();
  });
});
```

---

## DOM/Element Not Found

### Pattern: Element Not Found (Playwright)

**Error:**
```
Error: Element not found: button[name="Submit"]
```

**Common Causes:**
1. Wrong selector
2. Element not rendered yet
3. Element conditionally shown
4. Typo in selector

**Debug:**
```javascript
test('clicks button', async ({ page }) => {
  await page.goto('/form');
  await page.screenshot({ path: 'debug.png' }); // ← See what's on page
  await page.getByRole('button', { name: 'Submit' }).click();
});
```

**Fix:**
```javascript
// ❌ Wrong selector
await page.click('.submit-button'); // Class might have changed

// ✅ Use role-based selector
await page.getByRole('button', { name: 'Submit' }).click();

// ✅ Or wait for element
await page.waitForSelector('button:has-text("Submit")');
await page.click('button:has-text("Submit")');
```

---

## Data Issues

### Pattern: Unexpected Data Format

**Error:**
```
Expected object, received array
```

**Common Causes:**
1. API response changed
2. Mock data doesn't match reality
3. Data transformation incorrect

**Fix:**
```javascript
// ❌ Mock doesn't match API
mockApi.getUser.mockResolvedValue([{ id: '123' }]); // API returns object, not array

// ✅ Match actual API
mockApi.getUser.mockResolvedValue({ id: '123', name: 'John' });
```

---

## Environment Issues

### Pattern: Environment Variable Undefined

**Error:**
```
Cannot connect to database: undefined
```

**Common Causes:**
1. .env file not loaded
2. Wrong variable name
3. Test environment not configured

**Fix:**
```javascript
// ❌ Assumes env var exists
const dbUrl = process.env.DATABASE_URL; // Undefined in tests

// ✅ Provide fallback
const dbUrl = process.env.DATABASE_URL || 'postgresql://localhost:5432/test';

// ✅ Or check in setup
beforeAll(() => {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL not set');
  }
});
```

### Pattern: Module Not Found

**Error:**
```
Cannot find module './utils'
```

**Common Causes:**
1. Wrong import path
2. File moved/renamed
3. Missing file extension in import

**Fix:**
```javascript
// ❌ Wrong path
import { helper } from './utils'; // File is in ./utils/helper.ts

// ✅ Correct path
import { helper } from './utils/helper';

// ❌ Missing extension in some setups
import { helper } from './utils/helper';

// ✅ Add extension if needed
import { helper } from './utils/helper.js';
```
