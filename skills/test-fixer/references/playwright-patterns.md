# Playwright Flaky Test Patterns

## Core Principles

### Auto-Waiting

Playwright auto-waits for elements to be present, visible, stable, enabled, and receiving events—but has limitations:
- Doesn't handle asynchronous data loading
- Can't detect custom UI control readiness
- Misses dynamic content loading after apparent page readiness

### Always Use Locators with Auto-Waiting

Locators offer: lazy evaluation, automatic waiting, DOM change resilience, accessibility alignment.

## Anti-Patterns

### ❌ Arbitrary Timeouts
```javascript
await page.waitForTimeout(5000); // Fails on slower systems
```

### ❌ Brittle Selectors
```javascript
await page.locator('.MuiButton-contained.MuiButton-primary').click(); // Breaks with styling changes
await page.locator('//div[@class="results"]/div[3]').click(); // Fragile XPath
```

### ❌ Race Conditions with Element Collections
```javascript
for (const item of await page.getByRole('items').all()) {
  await item.click(); // May execute before all items loaded
}
```

## Best Practices

### ✅ Wait for Specific UI Indicators
```javascript
await page.click('#load-data');
await page.waitForSelector('[data-test="results-loaded"]');
```

Key methods: `waitForSelector`, `waitForFunction`, `waitForLoadState`, `waitForURL`, `waitForEvent`

### ✅ User-Centric Locators
```javascript
await page.getByRole('button', { name: 'Submit' }).click();
await page.getByLabel('Email address').fill('user@example.com');
await page.getByTestId('checkout-button').click();
```

Preference order:
1. Role/semantic locators (accessibility-aligned)
2. Text-based selection (user-facing)
3. Test IDs (`data-testid`)
4. Composed locators: `page.getByTestId('form').getByLabel('Email')`

### ✅ Safe Element Collections
```javascript
await page.waitForFunction(() =>
  document.querySelectorAll('li').length >= 5
);
for (const item of await page.getByRole('listitem').all()) {
  await item.click();
}
```

### ✅ Proper Timeout Configuration

Global config:
```javascript
export default defineConfig({
  timeout: 2 * 60 * 1000,
  expect: { timeout: 10 * 1000 }
});
```

Per-test override:
```javascript
test('slow operation', async ({ page }) => {
  test.setTimeout(5 * 60 * 1000);
});
```

Or use `test.slow()` to multiply default timeout by 3.

### ✅ Retry Mechanisms

```javascript
export default defineConfig({
  retries: process.env.CI ? 2 : 0
});
```

Results: passed, flaky (failed then passed), or failed.

### ✅ Debugging Configuration

```javascript
export default defineConfig({
  retries: 1,
  use: {
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'on-first-retry'
  }
});
```

View traces: `npx playwright show-trace path/to/trace.zip`

## Common Flakiness Causes

- Race conditions before application readiness
- Unstable selectors dependent on styling or DOM structure
- Network unpredictability affecting timing
- State contamination between tests
- Environmental differences (CI vs. local)
- Resource constraints

## Test Isolation

Launch each test in its own context/page. Shared state across tests is a common flakiness cause.

## External Dependencies

Use Playwright's request interception to control or mock external dependencies. Avoids flakiness from third-party outages or rate limits.
