# Vitest Coverage Guide

How coverage works in Vitest and how to configure it for retrofit workflows.

## Coverage Providers

Vitest supports two coverage providers:

### v8 (Default, Recommended)

```javascript
// vitest.config.ts
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      reportsDirectory: './coverage',
    },
  },
});
```

**Pros:**
- Fast (built into Node.js)
- No additional dependencies
- Accurate line/branch coverage

**Cons:**
- Slightly less detailed than Istanbul

### Istanbul

```javascript
// vitest.config.ts
export default defineConfig({
  test: {
    coverage: {
      provider: 'istanbul',
      reporter: ['text', 'json', 'html'],
    },
  },
});
```

**Pros:**
- Very detailed coverage reports
- Industry standard

**Cons:**
- Requires `@vitest/coverage-istanbul` package
- Slightly slower

---

## Configuration Options

### Essential Options

```javascript
export default defineConfig({
  test: {
    coverage: {
      enabled: false, // Don't auto-enable (use --coverage flag instead)
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      reportsDirectory: './coverage',

      // Include patterns
      include: ['src/**/*.{ts,tsx}', 'lib/**/*.{ts,tsx}'],

      // Exclude patterns (important!)
      exclude: [
        '**/*.test.{ts,tsx}',
        '**/*.spec.{ts,tsx}',
        '**/*.d.ts',
        '**/node_modules/**',
        '**/.next/**',
        '**/dist/**',
        '**/coverage/**',
        '**/*.config.{ts,js}',
      ],

      // Thresholds (optional - use with caution)
      statements: 80,
      branches: 80,
      functions: 80,
      lines: 80,
    },
  },
});
```

### Exclude Patterns

**Always exclude:**
- Test files (`.test.`, `.spec.`)
- Type definitions (`.d.ts`)
- Config files (`*.config.*`)
- Build artifacts (`dist/`, `.next/`)
- Dependencies (`node_modules/`)

**Consider excluding:**
- Server action wrappers (`actions.ts` - test logic instead)
- Generated code
- Mocks and test utilities

---

## Running Coverage

### Generate Reports

```bash
# With npm
npm test -- --coverage

# With pnpm
pnpm test --coverage

# Specific directory
npx vitest run --coverage lib/

# JSON output only (for parsing)
npx vitest run --coverage --coverage.reporter=json
```

### Reading JSON Output

Coverage JSON is in Istanbul format:

```json
{
  "path/to/file.ts": {
    "path": "path/to/file.ts",
    "statementMap": { ... },
    "fnMap": { ... },
    "branchMap": { ... },
    "s": { "0": 5, "1": 0, "2": 3 },  // Statement hit counts
    "f": { "0": 2, "1": 0 },          // Function hit counts
    "b": { "0": [3, 0] }              // Branch hit counts
  }
}
```

**Key fields:**
- `s` - Statement coverage (line hit counts)
- `f` - Function coverage (function call counts)
- `b` - Branch coverage (conditional branches)

**Reading coverage %:**
```python
statements = file_data.get('s', {})
total = len(statements)
covered = sum(1 for count in statements.values() if count > 0)
coverage_pct = (covered / total) * 100
```

---

## HTML Reports

```bash
npx vitest run --coverage
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
start coverage/index.html  # Windows
```

**HTML reports show:**
- Overall coverage percentage
- Per-file coverage breakdown
- Highlighted uncovered lines (red)
- Partially covered branches (yellow)

---

## Coverage in CI

```yaml
# .github/workflows/test.yml
- name: Run tests with coverage
  run: npm test -- --coverage

- name: Upload coverage reports
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage/coverage-final.json
```

---

## Common Issues

### "Coverage stuck at 0%"

**Cause:** Test files not being run

**Fix:**
```bash
# Verify tests run first
npm test

# Then add coverage flag
npm test -- --coverage
```

### "Coverage includes test files"

**Cause:** Missing exclude patterns

**Fix:**
```javascript
exclude: [
  '**/*.test.{ts,tsx}',
  '**/*.spec.{ts,tsx}',
]
```

### "Coverage lower than expected"

**Causes:**
1. Test files match include patterns
2. Generated/config files included
3. Node modules included
4. Tests not actually running functions

**Debug:**
- Check HTML report to see what's included
- Verify exclude patterns
- Add `console.log` in functions to confirm they run

---

## Interpreting Coverage

### Good Coverage (80%+)

Indicates:
- Most code paths exercised
- Edge cases likely tested
- Reasonable confidence in behavior

**Does NOT guarantee:**
- Tests are meaningful
- Edge cases all covered
- No bugs exist

### Low Coverage (<50%)

Indicates:
- Many code paths never executed
- Limited testing
- Higher bug risk

**Could mean:**
- Code is new/untested
- Tests focus on specific areas
- Dead code exists

### Coverage by Type

**Statements:** Lines of code executed
**Branches:** If/else paths taken
**Functions:** Functions called
**Lines:** Physical lines hit (vs statements)

**Target all 4 metrics for comprehensive coverage.**

---

## Best Practices

1. **Don't aim for 100%** - Diminishing returns past 80%
2. **Focus on critical paths** - Business logic > config files
3. **Use HTML reports** - Visual feedback is helpful
4. **Combine with mutation testing** - Coverage + mutation = confidence
5. **Exclude intelligently** - Don't count what doesn't matter
6. **Monitor trends** - Track coverage over time, not just absolute %

---

## Quick Reference

| Task | Command |
|------|---------|
| Generate coverage | `npm test -- --coverage` |
| JSON only | `npm test -- --coverage --coverage.reporter=json` |
| HTML report | `npm test -- --coverage && open coverage/index.html` |
| Specific directory | `npm test -- --coverage lib/` |
| Check threshold | `npm test -- --coverage --coverage.statements=80` |

**Coverage JSON location:** `./coverage/coverage-final.json`
**HTML report location:** `./coverage/index.html`
