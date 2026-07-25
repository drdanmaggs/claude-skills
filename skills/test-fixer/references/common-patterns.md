# Cross-Framework Flaky Test Patterns

## Universal Principles

### Test Isolation
Each test must be independent and self-contained:
- Create own test data
- Clean up after execution
- No shared state between tests
- Fresh environment per test

### Avoid Time-Based Waits
Never use arbitrary timeouts:
- Use condition-based waits instead
- Poll for expected state
- Wait for specific indicators

### Control Non-Determinism
Sources of randomness that cause flakiness:
- Current timestamps
- Random IDs/values
- External API responses
- Async timing
- Parallel execution order

## Common Flakiness Categories

### 1. Timing Issues

**Problem:** Code assumes operations complete instantly
```javascript
// ❌ Assumes immediate completion
clickButton();
expect(getResult()).toBe('success'); // May fail
```

**Solution:** Wait for completion
```javascript
// ✅ Wait for operation
await clickButton();
await waitFor(() => expect(getResult()).toBe('success'));
```

### 2. Race Conditions

**Problem:** Multiple async operations compete
```javascript
// ❌ Race condition
Promise.all([updateA(), updateB()]);
const result = getState(); // Which update won?
```

**Solution:** Define execution order
```javascript
// ✅ Sequential when order matters
await updateA();
await updateB();
const result = getState();
```

### 3. State Pollution

**Problem:** Tests affect each other's state
```javascript
// ❌ Shared mutable state
let counter = 0;

test('increments', () => {
  counter++; // Affects next test
  expect(counter).toBe(1);
});

test('starts at zero', () => {
  expect(counter).toBe(0); // Fails if runs after previous test
});
```

**Solution:** Isolate state per test
```javascript
// ✅ Independent state
test('increments', () => {
  let counter = 0;
  counter++;
  expect(counter).toBe(1);
});

test('starts at zero', () => {
  let counter = 0;
  expect(counter).toBe(0);
});
```

### 4. External Dependencies

**Problem:** Tests depend on external services
```javascript
// ❌ Real API call
test('fetches user', async () => {
  const user = await api.fetchUser('123'); // Network flakiness
  expect(user.name).toBe('John');
});
```

**Solution:** Mock external dependencies
```javascript
// ✅ Mocked dependency
test('fetches user', async () => {
  mockApi.fetchUser.mockResolvedValue({ name: 'John' });
  const user = await api.fetchUser('123');
  expect(user.name).toBe('John');
});
```

### 5. Timestamp Precision

**Problem:** Strict timestamp matching
```javascript
// ❌ Millisecond precision
const now = new Date().toISOString();
const result = createRecord();
expect(result.createdAt).toBe(now); // Likely to fail
```

**Solution:** Fuzzy time matching
```javascript
// ✅ Reasonable time window
const before = Date.now();
const result = createRecord();
const after = Date.now();

const createdAt = new Date(result.createdAt).getTime();
expect(createdAt).toBeGreaterThanOrEqual(before);
expect(createdAt).toBeLessThanOrEqual(after);
```

Or mock time:
```javascript
// ✅ Controlled time
mockDate('2026-02-05T10:00:00Z');
const result = createRecord();
expect(result.createdAt).toBe('2026-02-05T10:00:00Z');
```

### 6. Array/Collection Order

**Problem:** Assuming collection order
```javascript
// ❌ Order-dependent assertion
const results = await fetchItems();
expect(results).toEqual([{ id: 1 }, { id: 2 }, { id: 3 }]);
```

**Solution:** Order-independent checks
```javascript
// ✅ Order-independent
const results = await fetchItems();
expect(results).toHaveLength(3);
expect(results).toEqual(expect.arrayContaining([
  expect.objectContaining({ id: 1 }),
  expect.objectContaining({ id: 2 }),
  expect.objectContaining({ id: 3 })
]));
```

### 7. Floating-Point Arithmetic

**Problem:** Precise equality checks
```javascript
// ❌ Floating-point comparison
expect(0.1 + 0.2).toBe(0.3); // Fails due to precision
```

**Solution:** Approximate comparison
```javascript
// ✅ Tolerance-based comparison
expect(0.1 + 0.2).toBeCloseTo(0.3, 5);
```

### 8. Resource Cleanup

**Problem:** Tests leave artifacts
```javascript
// ❌ No cleanup
test('creates file', async () => {
  await fs.writeFile('/tmp/test.txt', 'data');
  const content = await fs.readFile('/tmp/test.txt');
  expect(content).toBe('data');
  // File remains for next test
});
```

**Solution:** Proper teardown
```javascript
// ✅ Cleanup after test
test('creates file', async () => {
  const tempFile = '/tmp/test-' + randomUUID() + '.txt';

  try {
    await fs.writeFile(tempFile, 'data');
    const content = await fs.readFile(tempFile);
    expect(content).toBe('data');
  } finally {
    await fs.unlink(tempFile);
  }
});
```

### 9. Parallel Execution Conflicts

**Problem:** Tests compete for resources
```javascript
// ❌ Shared resource
test('test A', () => {
  writeToSharedDB('key', 'valueA');
  expect(readFromSharedDB('key')).toBe('valueA');
});

test('test B', () => {
  writeToSharedDB('key', 'valueB');
  expect(readFromSharedDB('key')).toBe('valueB');
});
```

**Solution:** Unique identifiers
```javascript
// ✅ Isolated resources
test('test A', () => {
  const key = 'key-' + randomUUID();
  writeToSharedDB(key, 'valueA');
  expect(readFromSharedDB(key)).toBe('valueA');
});

test('test B', () => {
  const key = 'key-' + randomUUID();
  writeToSharedDB(key, 'valueB');
  expect(readFromSharedDB(key)).toBe('valueB');
});
```

### 10. Environment Differences

**Problem:** Tests behave differently across environments
```javascript
// ❌ Environment-dependent
test('runs fast', () => {
  const start = Date.now();
  performOperation();
  const duration = Date.now() - start;
  expect(duration).toBeLessThan(100); // Fails on slower CI
});
```

**Solution:** Environment-agnostic assertions
```javascript
// ✅ Focus on behavior, not performance
test('completes successfully', async () => {
  const result = await performOperation();
  expect(result).toBe('success');
});
```

## Detection Checklist

Test is likely flaky if:
- ✓ Passes locally, fails in CI (or vice versa)
- ✓ Passes/fails randomly on same commit
- ✓ Passes when run alone, fails in suite
- ✓ Passes when run sequentially, fails in parallel
- ✓ Uses `setTimeout` or hard-coded delays
- ✓ Depends on execution order
- ✓ Shares state with other tests
- ✓ Makes real network calls
- ✓ Uses current time without mocking
- ✓ Has overly precise assertions

## Fix Priority

High priority:
1. Tests blocking CI frequently
2. Tests in critical paths
3. Tests with obvious fixes (hard waits → proper waits)

Medium priority:
4. Occasionally flaky tests
5. Tests requiring refactoring

Low priority:
6. Rarely flaky tests
7. Tests in low-traffic areas

Track metrics: how many PRs each flaky test blocks.
