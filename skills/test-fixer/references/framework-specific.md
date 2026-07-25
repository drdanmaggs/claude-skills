# Framework-Specific Debugging

## Version Detection (NEW)

**Before debugging framework issues, identify versions:**

```bash
# Check installed framework versions
cat package.json | grep -E "(playwright|vitest|@testing-library)" | head -5

# Or check specific framework
npm list playwright
npm list vitest
```

**Why version matters:**
- Behavior changes between major versions
- APIs get deprecated/renamed
- Context7 queries can be version-specific

**Example:**
- Playwright v1.40 vs v1.42: Strict mode became default
- Vitest v0.x vs v1.x: Mock hoisting behavior changed
- Next.js 15 vs 16: `middleware.ts` renamed to `proxy.ts`

**Use version in Context7 queries when:**
- Error mentions deprecated API
- Behavior changed after upgrade
- Documentation conflicts with observed behavior

**Query pattern:**
```
libraryId: "/microsoft/playwright/v1.42.0"  # Version-specific
vs
libraryId: "/microsoft/playwright"  # Latest stable
```

See [context7-integration.md](context7-integration.md) for version-specific query patterns.

---

## Playwright (E2E Tests)

### Common Playwright Failures

#### 1. Page Not Loaded

**Error:**
```
Navigation timeout of 30000ms exceeded
```

**Causes:**
- Page URL wrong
- Server not running
- Slow page load
- JavaScript error blocking load

**Debug:**
```javascript
test('loads page', async ({ page }) => {
  await page.goto('/dashboard', { waitUntil: 'networkidle' });
  await page.screenshot({ path: 'debug.png' }); // See what loaded
});
```

**Fix:**
```javascript
// ❌ Default wait might not be enough
await page.goto('/dashboard');

// ✅ Wait for specific state
await page.goto('/dashboard', { waitUntil: 'networkidle' });
// or
await page.goto('/dashboard');
await page.waitForSelector('[data-testid="dashboard-loaded"]');
```

#### 2. Element Not Visible/Enabled

**Error:**
```
Element is not visible
Element is disabled
```

**Causes:**
- Element hidden by CSS
- Element covered by another element
- Element not yet rendered
- Button actually disabled

**Debug:**
```javascript
test('clicks button', async ({ page }) => {
  const button = page.getByRole('button', { name: 'Submit' });

  // Check visibility
  console.log('Visible:', await button.isVisible());
  console.log('Enabled:', await button.isEnabled());

  // Take screenshot
  await page.screenshot({ path: 'debug.png' });
});
```

**Fix:**
```javascript
// ❌ Clicks too early
await page.getByRole('button', { name: 'Submit' }).click();

// ✅ Wait for element to be ready
await page.getByRole('button', { name: 'Submit' }).waitFor({ state: 'visible' });
await page.getByRole('button', { name: 'Submit' }).click();

// ✅ Or force click if element is intentionally hidden
await page.getByRole('button', { name: 'Submit' }).click({ force: true });
```

#### 3. Multiple Elements Match

**Error:**
```
strict mode violation: getByRole('button') resolved to 3 elements
```

**Causes:**
- Selector too broad
- Multiple matching elements on page

**Fix:**
```javascript
// ❌ Ambiguous selector
await page.getByRole('button').click();

// ✅ More specific
await page.getByRole('button', { name: 'Submit' }).click();

// ✅ Or use first/nth
await page.getByRole('button').first().click();

// ✅ Or scope to container
await page.getByTestId('login-form')
  .getByRole('button', { name: 'Submit' })
  .click();
```

#### 4. Assertion Failed on Element

**Error:**
```
Expected element to contain text "Success"
Received: "Loading..."
```

**Causes:**
- Content not loaded yet
- Wrong element selected
- Text content different than expected

**Debug:**
```javascript
test('shows success message', async ({ page }) => {
  await page.click('[data-testid="submit"]');

  const message = page.getByTestId('message');
  console.log('Text content:', await message.textContent());

  await expect(message).toContainText('Success');
});
```

**Fix:**
```javascript
// ❌ Checks immediately
await page.click('[data-testid="submit"]');
await expect(page.getByTestId('message')).toContainText('Success');

// ✅ Wait for content to appear
await page.click('[data-testid="submit"]');
await page.waitForSelector('[data-testid="message"]:has-text("Success")');
await expect(page.getByTestId('message')).toContainText('Success');

// ✅ Or use Playwright's auto-waiting in expect
await page.click('[data-testid="submit"]');
await expect(page.getByTestId('message')).toContainText('Success', { timeout: 10000 });
```

#### 5. Browser Context Issues

**Error:**
```
Target page, context or browser has been closed
```

**Causes:**
- Page closed before test completes
- Browser crashed
- Test didn't wait for navigation

**Fix:**
```javascript
// ❌ Page navigates away
await page.click('a[href="/logout"]');
await expect(page.locator('h1')).toContainText('Login'); // Page already gone

// ✅ Wait for navigation
await Promise.all([
  page.waitForNavigation(),
  page.click('a[href="/logout"]')
]);
await expect(page.locator('h1')).toContainText('Login');
```

---

## Vitest (Unit/Integration Tests)

### Worker-Scoped Fixtures (Parallel Isolation)

Pattern for integration tests that need database isolation:

```typescript
// tests/helpers/vitest-worker-fixture.ts
export const test = baseTest.extend<{}, { workerHousehold: IsolatedTestHousehold }>({
  workerHousehold: [async ({}, use) => {
    const household = await createIsolatedTestHousehold(...);
    await use(household);
    await cleanupIsolatedTestHousehold(...);
  }, { scope: 'worker' }],
});
```

**When to recommend:**
- Tests fail in parallel but pass individually
- Cleanup doesn't happen on crash/timeout
- Integration tests using beforeAll/afterAll

**Reference:** Vitest supports same worker-scoped fixtures as Playwright. See official docs: https://vitest.dev/guide/test-context.html#test-extend

### Common Vitest Failures

#### 1. Module Mock Issues

**Error:**
```
Cannot find module './api' from 'src/users.ts'
```

**Causes:**
- Mock path incorrect
- Module not properly hoisted
- Named vs default export mismatch

**Debug:**
```javascript
// Check what's being imported
import * as api from './api';
console.log('API exports:', Object.keys(api));
```

**Fix:**
```javascript
// ❌ Wrong mock path
vi.mock('../api', () => ({ ... }));

// ✅ Correct path (relative to test file)
vi.mock('./api', () => ({
  fetchUser: vi.fn()
}));

// ❌ Default export mock for named export
vi.mock('./api', () => ({
  default: vi.fn()
}));

// ✅ Match actual exports
vi.mock('./api', () => ({
  fetchUser: vi.fn(), // Named export
  default: vi.fn()    // Default export
}));
```

#### 2. Spy/Mock Not Reset

**Error:**
```
Expected 1 call, received 3 calls
```

**Causes:**
- Mock called in previous test
- Missing mock.mockClear() or mock.mockReset()

**Fix:**
```javascript
// ❌ Mock state carries over
const mockFn = vi.fn();

test('first test', () => {
  mockFn();
  expect(mockFn).toHaveBeenCalledTimes(1);
});

test('second test', () => {
  mockFn();
  expect(mockFn).toHaveBeenCalledTimes(1); // FAILS: actually 2
});

// ✅ Reset between tests
const mockFn = vi.fn();

afterEach(() => {
  mockFn.mockClear(); // Clear call history
  // or mockFn.mockReset(); // Also clears implementation
  // or mockFn.mockRestore(); // Restores original
});

// ✅ Or use clearMocks config
// vitest.config.ts
export default defineConfig({
  test: {
    clearMocks: true
  }
});
```

#### 3. Async Test Didn't Wait

**Error:**
```
Test finished before assertions completed
```

**Causes:**
- Missing await on async function
- Promise not returned
- Test not marked async

**Fix:**
```javascript
// ❌ Test finishes before promise resolves
test('loads data', () => {
  loadData().then(data => {
    expect(data).toBeDefined(); // Never runs
  });
});

// ✅ Return promise
test('loads data', () => {
  return loadData().then(data => {
    expect(data).toBeDefined();
  });
});

// ✅ Or use async/await
test('loads data', async () => {
  const data = await loadData();
  expect(data).toBeDefined();
});
```

#### 4. Timer/Date Mock Issues

**Error:**
```
Expected "2026-02-05", received "2026-02-06"
```

**Causes:**
- Fake timers not set up
- System time advanced
- Mock not applied early enough

**Fix:**
```javascript
// ❌ No time control
test('creates timestamp', () => {
  const timestamp = createTimestamp();
  expect(timestamp).toBe('2026-02-05'); // Fails next day
});

// ✅ Mock system time
test('creates timestamp', () => {
  vi.setSystemTime(new Date('2026-02-05'));
  const timestamp = createTimestamp();
  expect(timestamp).toBe('2026-02-05');
  vi.useRealTimers(); // Clean up
});

// ✅ Or use fake timers for setTimeout/setInterval
test('delays execution', () => {
  vi.useFakeTimers();
  const callback = vi.fn();

  setTimeout(callback, 1000);
  vi.advanceTimersByTime(1000);

  expect(callback).toHaveBeenCalled();
  vi.useRealTimers();
});
```

#### 5. Import Order Issues

**Error:**
```
Mock was not applied
```

**Causes:**
- Mock declared after import
- vi.mock() needs to be hoisted

**Fix:**
```javascript
// ❌ Mock too late
import { getUser } from './api';
vi.mock('./api'); // Too late, already imported

// ✅ Mock before import
vi.mock('./api', () => ({
  getUser: vi.fn()
}));
import { getUser } from './api';

// ✅ Or use top-level vi.mock (auto-hoisted)
vi.mock('./api');

import { getUser } from './api';
// Now you can configure mock
getUser.mockResolvedValue({ id: '123' });
```

#### 6. Wrong Matcher Used

**Error:**
```
Received value does not match expected type
```

**Causes:**
- Using toBe() for objects/arrays (checks reference equality)
- Wrong matcher for the assertion

**Fix:**
```javascript
// ❌ Wrong matcher
expect({ id: '123' }).toBe({ id: '123' }); // FAILS (different reference)
expect([1, 2, 3]).toBe([1, 2, 3]); // FAILS

// ✅ Correct matcher
expect({ id: '123' }).toEqual({ id: '123' }); // Deep equality
expect([1, 2, 3]).toEqual([1, 2, 3]);

// ✅ Or partial match
expect({ id: '123', name: 'John' }).toMatchObject({ id: '123' });
expect([1, 2, 3, 4]).toEqual(expect.arrayContaining([1, 2, 3]));
```

---

## Testing Library (React/Vue/etc.)

### Common Testing Library Failures

#### 1. Element Not Found

**Error:**
```
Unable to find an element with text: "Submit"
```

**Causes:**
- Element not rendered
- Wrong query method
- Async rendering not awaited

**Debug:**
```javascript
test('renders button', () => {
  render(<MyComponent />);
  screen.debug(); // Print entire DOM
  screen.getByText('Submit');
});
```

**Fix:**
```javascript
// ❌ Element not rendered yet
render(<AsyncComponent />);
const button = screen.getByText('Submit'); // FAILS

// ✅ Wait for element
render(<AsyncComponent />);
const button = await screen.findByText('Submit'); // Waits up to 1000ms

// ✅ Or check if it exists
const button = screen.queryByText('Submit'); // Returns null if not found
expect(button).not.toBeNull();
```

#### 2. Multiple Elements Found

**Error:**
```
Found multiple elements with text: "Delete"
```

**Causes:**
- Query too broad
- Multiple instances of same text

**Fix:**
```javascript
// ❌ Ambiguous query
screen.getByText('Delete');

// ✅ Use getAllByText and pick one
const deleteButtons = screen.getAllByText('Delete');
expect(deleteButtons).toHaveLength(2);
deleteButtons[0].click();

// ✅ Or scope query
within(screen.getByTestId('user-card')).getByText('Delete');

// ✅ Or use more specific role
screen.getByRole('button', { name: 'Delete User' });
```

#### 3. Act Warning

**Error:**
```
Warning: An update to Component inside a test was not wrapped in act(...)
```

**Causes:**
- State update after test completes
- Async update not awaited
- Missing cleanup

**Fix:**
```javascript
// ❌ Async update not awaited
test('updates state', () => {
  render(<Component />);
  fireEvent.click(screen.getByText('Load'));
  // Component updates state asynchronously
  expect(screen.getByText('Loaded')).toBeInTheDocument(); // FAILS with act warning
});

// ✅ Wait for update
test('updates state', async () => {
  render(<Component />);
  fireEvent.click(screen.getByText('Load'));
  await screen.findByText('Loaded'); // Waits for async update
  expect(screen.getByText('Loaded')).toBeInTheDocument();
});

// ✅ Or use waitFor
test('updates state', async () => {
  render(<Component />);
  fireEvent.click(screen.getByText('Load'));
  await waitFor(() => {
    expect(screen.getByText('Loaded')).toBeInTheDocument();
  });
});
```

---

## Quick Reference

### Playwright Debug Commands
```javascript
await page.pause(); // Pause execution, open inspector
await page.screenshot({ path: 'debug.png' });
console.log(await page.content()); // Print HTML
console.log(await element.textContent());
```

### Vitest Debug Commands
```javascript
console.log(value);
vi.mock() // Check mock setup
expect(mock).toHaveBeenCalledWith() // Inspect mock calls
screen.debug(); // Testing Library: print DOM
```

### Common Fix Patterns

**Timing issues:**
- Add `await` to async operations
- Use `waitFor`, `findBy*`, or `waitForSelector`
- Increase timeout if needed

**Mock issues:**
- Check mock path is correct
- Verify mock matches actual exports
- Reset mocks between tests

**Assertion issues:**
- Use `toEqual()` for objects/arrays, not `toBe()`
- Use flexible matchers (`toMatchObject`, `arrayContaining`)
- Check expected vs actual types match
