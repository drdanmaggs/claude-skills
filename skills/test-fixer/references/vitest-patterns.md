# Vitest Flaky Test Patterns

## Definition

Flaky test: returns non-deterministic result even when no code has changed. Multiple runs return different results.

## Root Causes

- Environment issues
- Networking problems
- Infrastructure instability
- Asynchronous operations
- Concurrency issues (async wait, race conditions, atomicity violations, deadlocks)

## Anti-Patterns

### ❌ Hard Waits
```javascript
await new Promise(resolve => setTimeout(resolve, 1000)); // Arbitrary wait
```

### ❌ Overly Strict Assertions
```javascript
expect(value).toBe(0.1 + 0.2); // Floating-point precision issues
expect(response.timestamp).toBe('2026-02-05T10:30:45.123Z'); // Millisecond precision fails
expect(array).toEqual([1, 2, 3]); // When order doesn't matter
```

### ❌ Shared State Between Tests
```javascript
let sharedUser; // Tests mutating shared state

test('create user', () => {
  sharedUser = createUser(); // Affects other tests
});

test('update user', () => {
  updateUser(sharedUser); // Depends on previous test
});
```

### ❌ Unmanaged Test Artifacts
```javascript
test('creates file', async () => {
  await fs.writeFile('test-data.json', data);
  // No cleanup - affects subsequent tests
});
```

## Best Practices

### ✅ Use Polling Methods
```javascript
import { waitFor } from '@testing-library/react';

await waitFor(() => {
  expect(screen.getByText('Loaded')).toBeInTheDocument();
}, { timeout: 5000, interval: 100 });
```

### ✅ Flexible Assertions
```javascript
expect(value).toBeCloseTo(0.3, 5); // Floating-point comparison

expect(response).toMatchObject({
  userId: expect.any(String),
  timestamp: expect.stringMatching(/^\d{4}-\d{2}-\d{2}/)
});

expect(array).toEqual(expect.arrayContaining([1, 2, 3])); // Order-independent
```

### ✅ Fake Timers
```javascript
import { vi } from 'vitest';

test('timer-dependent code', () => {
  vi.useFakeTimers();

  const callback = vi.fn();
  setTimeout(callback, 1000);

  vi.advanceTimersByTime(1000);
  expect(callback).toHaveBeenCalled();

  vi.useRealTimers();
});
```

### ✅ Mock Dates
```javascript
test('date-dependent logic', () => {
  vi.setSystemTime(new Date('2026-02-05'));

  const result = getTodayFormatted();
  expect(result).toBe('2026-02-05');

  vi.useRealTimers();
});
```

### ✅ Test Independence
```javascript
describe('user management', () => {
  let testUser;

  beforeEach(() => {
    testUser = createTestUser(); // Fresh state per test
  });

  afterEach(() => {
    deleteTestUser(testUser.id); // Clean up
  });

  test('updates user', () => {
    updateUser(testUser);
    expect(testUser.status).toBe('active');
  });
});
```

### ✅ Proper Setup/Teardown
```javascript
beforeAll(async () => {
  // One-time expensive setup (DB connection)
  await connectToTestDatabase();
});

afterAll(async () => {
  // One-time cleanup
  await closeTestDatabase();
});

beforeEach(async () => {
  // Per-test setup
  await cleanDatabase();
  testData = await seedTestData();
});

afterEach(async () => {
  // Per-test cleanup
  await cleanupTestArtifacts();
});
```

### ✅ Mock External Dependencies
```javascript
import { vi } from 'vitest';
import { fetchUser } from './api';

vi.mock('./api', () => ({
  fetchUser: vi.fn()
}));

test('handles API response', async () => {
  fetchUser.mockResolvedValue({ id: '123', name: 'Test' });

  const result = await getUserData('123');
  expect(result.name).toBe('Test');
});
```

### ✅ Seeded Randomness
```javascript
import { faker } from '@faker-js/faker';

beforeEach(() => {
  faker.seed(123); // Consistent random data per test
});

test('generates predictable data', () => {
  const email = faker.internet.email();
  expect(email).toBe('expected@example.com'); // Reproducible
});
```

## Parallel Test Execution

Testing in parallel and random order introduces:
- Inconsistent system states
- Race conditions where concurrent tests interfere
- Resource contention

**Solutions:**
- Isolate test data (use unique IDs per test)
- Use transactions that rollback
- Run tests sequentially when necessary: `test.sequential()`
- Implement proper locking for shared resources

## Detection Strategies

### Disable Retries for Accurate Detection
```javascript
export default defineConfig({
  test: {
    retry: 0 // Retries hide flakiness
  }
});
```

### Monitor Flaky Patterns
- Track tests that pass/fail on same commit SHA
- Count PR blocks per flaky test to prioritize fixes
- Use continuous monitoring rather than periodic cleanup

## Test Data Isolation

**Critical for integration tests:**
```javascript
import { createIsolatedTestHousehold } from './helpers';

let household;

beforeAll(async () => {
  household = await createIsolatedTestHousehold();
});

afterAll(async () => {
  await cleanupIsolatedTestHousehold(household.id);
});

test('operates on isolated data', async () => {
  // Uses household.id - no cross-test pollution
});
```

Never use shared environment variables like `TEST_USER_ID` - causes test pollution.
