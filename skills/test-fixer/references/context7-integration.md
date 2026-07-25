# Context7 Integration for Test Debugging

## When to Use Context7

Context7 should be consulted when:
1. **Structural issues** - Error suggests framework-specific behavior misunderstanding
2. **Version-specific gotchas** - Recently upgraded framework version
3. **Best practices unclear** - Unsure of recommended pattern for framework
4. **Documentation needed** - Need to verify expected behavior against official docs

## DO NOT Use Context7 for:
- Logic bugs in your own code (use Explore agent)
- Simple syntax errors (read the error message)
- Configuration issues (check project config files)
- One-off typos or obvious mistakes

## Integration Points in Workflow

### Step 2: Root Cause Analysis
**Use when:** Need to understand expected framework behavior

**Query pattern:**
```
mcp__context7__query-docs(
  libraryId: "/[org]/[framework]",  # e.g., "/microsoft/playwright" or "/nextjs/next.js"
  query: "How does [framework] handle [specific pattern from error]?"
)
```

**Example queries:**
- "Playwright strict mode violations with multiple elements"
- "Next.js 16 middleware vs proxy difference"
- "React Testing Library act warnings async state updates"
- "Vitest mock hoisting with ES modules"

### Step 4: Failing Test Debugging
**Use when:** Error message references framework-specific concept

**Query pattern:**
```
mcp__context7__query-docs(
  libraryId: "/[framework]",
  query: "[Error message key phrase] best practices"
)
```

**Example queries:**
- "Playwright waitForSelector vs waitForLoadState difference"
- "Vitest mockResolvedValue not working with import.meta"
- "Next.js server components testing strategy"

### Step 5: Flaky Test Patterns
**Use when:** Timing/race condition seems framework-related

**Query pattern:**
```
mcp__context7__query-docs(
  libraryId: "/[framework]",
  query: "how to avoid flaky tests with [specific async pattern]"
)
```

**Example queries:**
- "Playwright auto-waiting behavior for dynamic content"
- "Vitest fake timers with async functions"
- "React Testing Library waiting for element with animations"

## Common Framework Library IDs

**For this project (Family Meal Planner):**
- Next.js: `/vercel/next.js` (check version in package.json)
- Playwright: `/microsoft/playwright`
- Vitest: `/vitest-dev/vitest`
- React Testing Library: `/testing-library/react-testing-library`
- Supabase: `/supabase/supabase-js`

**Other common frameworks:**
- Jest: `/jestjs/jest`
- Cypress: `/cypress-io/cypress`
- Testing Library Core: `/testing-library/dom-testing-library`
- React: `/facebook/react`

**Resolve unknown frameworks:**
```
mcp__context7__resolve-library-id(
  libraryName: "[package name from error]",
  query: "[user's original question about the test]"
)
```

## Context7 Usage Pattern

**1. Identify the framework** from error stack trace or test file imports

**2. Resolve library ID** (if not in common list above):
```
const libs = await mcp__context7__resolve-library-id({
  libraryName: "playwright",
  query: "Why is my Playwright test failing with 'element not found'?"
});
// Returns: /microsoft/playwright
```

**3. Query documentation:**
```
const docs = await mcp__context7__query-docs({
  libraryId: "/microsoft/playwright",
  query: "waitForSelector best practices for dynamic content"
});
// Returns: relevant documentation snippets and examples
```

**4. Apply knowledge** to test fix

**5. Record in memory** if framework-specific gotcha:
```markdown
# memory/[project-hash]/framework-gotchas.md
## Playwright - waitForSelector
**Issue:** waitForSelector times out on dynamically loaded elements
**Solution:** Use `state: 'visible'` option or waitForLoadState first
**Documentation:** [Context7 link]
**Date learned:** 2026-02-09
```

## Query Best Practices

### Good Queries (Specific)
✅ "How does Playwright handle file upload dialogs?"
✅ "Vitest mock factory function hoisting behavior"
✅ "Next.js 16 dynamic route testing with App Router"

### Bad Queries (Too Broad)
❌ "Playwright testing"
❌ "Why is my test failing"
❌ "Vitest"

### Query Structure Template
```
[Framework feature/API] + [specific problem/pattern] + [context from error]
```

**Examples:**
- "Playwright getByRole strict mode" + "multiple elements found" + "button selector"
- "Vitest mockImplementation" + "not applying to import" + "ES module"
- "React Testing Library findBy" + "timeout" + "async component render"

## Error Pattern → Context7 Mapping

| Error Pattern | Framework | Query Template |
|---------------|-----------|----------------|
| "strict mode violation" | Playwright | "strict mode selector best practices" |
| "act(...)" warning | React Testing Library | "act warning async state updates" |
| "mockResolvedValue not called" | Vitest | "mock function not applying to imports" |
| "Navigation timeout" | Playwright | "page navigation timeout handling" |
| "Cannot find module" | Vitest | "ES module import mocking" |
| "useEffect cleanup" | React Testing Library | "cleanup function testing patterns" |
| "ECONNRESET" | Playwright | "webServer graceful shutdown" |
| "waitForSelector timeout" | Playwright | "waiting for dynamic content" |
| "mockReturnValue not working" | Vitest | "mock hoisting with ES modules" |
| "element not visible" | Playwright | "visibility vs presence waiting" |

## Integration with Sequential Thinking

**Within ST thought process:**
```
Thought 5: Need to understand Playwright's expected behavior for this selector
  → Using Context7 to query /microsoft/playwright
  → Query: "getByRole button strict mode multiple matches"
  → Result: Documentation shows need to use { name: 'specific text' } to disambiguate
  → Conclusion: Test needs more specific selector, not a bug in Playwright
```

**Example from real debugging session:**
```markdown
Thought 7: Error "strict mode violation" suggests Playwright issue.

Using Context7:
- Resolved library: /microsoft/playwright
- Query: "strict mode getByRole multiple elements handling"
- Result: Documentation recommends:
  * Use `{ name: 'button text' }` option to disambiguate
  * Or use `.first()` if order is predictable
  * Strict mode is intentional to catch ambiguous selectors

Conclusion: Test selector is too broad. Need to add { name } option.
This is not a Playwright bug - it's working as designed to catch test quality issues.
```

## Caching Results

**Context7 results should inform memory:**
- If solution found in Context7, record it in `framework-gotchas.md`
- Future similar issues can reference memory first (faster)
- Context7 is backup when memory doesn't have answer

**Workflow:**
1. Check memory first (Step 0.5)
2. If no memory entry, use Context7 (Step 2/4/5)
3. After fix, record Context7 findings in memory
4. Next time: memory hit, skip Context7 (faster)

## Version-Specific Queries

**Always check project version before querying:**
```bash
# Check package.json
cat package.json | grep "playwright"
# "playwright": "^1.42.0"
```

**Use version in library ID when critical:**
```
libraryId: "/microsoft/playwright/v1.42.0"
```

**Most recent versions use default:**
```
libraryId: "/microsoft/playwright"  # Latest stable
```

**When version matters:**
- Major version upgrades (breaking changes likely)
- Error mentions specific API deprecated/changed
- Framework behavior differs from expectations

## Framework Detection from Error

**Stack trace analysis:**
```
Error: strict mode violation
    at getByRole (/node_modules/@playwright/test/lib/locators.js:123:45)
    at tests/e2e/meal-planning.spec.ts:42:18
```
→ Framework: Playwright (`@playwright/test`)

**Import analysis:**
```typescript
import { test, expect } from '@playwright/test';
```
→ Framework: Playwright

**File path heuristics:**
- `tests/e2e/*.spec.ts` → Likely Playwright or Cypress
- `*.test.ts` → Likely Vitest or Jest
- `*.integration.test.ts` → Likely Vitest with Supabase

## Real-World Examples

### Example 1: Playwright Strict Mode
**Error:** "strict mode violation: locator.click resolved to 3 elements"

**Context7 Query:**
```
libraryId: "/microsoft/playwright"
query: "strict mode getByRole multiple elements best practices"
```

**Result:**
- Strict mode prevents ambiguous selectors
- Use `{ name: 'text' }` to disambiguate
- Or use `.first()` if order matters

**Fix Applied:**
```typescript
// Before
await page.getByRole('button').click();

// After
await page.getByRole('button', { name: 'Submit' }).click();
```

**Recorded in memory:**
```markdown
## Playwright - Strict Mode Selector Ambiguity
**Pattern:** getByRole resolves to multiple elements
**Cause:** Selector too broad without { name } option
**Fix:** Add { name: 'specific text' } to disambiguate
**Documentation:** /microsoft/playwright - strict mode best practices
**Frequency:** Common
**Occurrences:** 3
```

### Example 2: Next.js 16 Middleware Rename
**Error:** Routes not protected, middleware not running

**Context7 Query:**
```
libraryId: "/vercel/next.js/v16"
query: "middleware.ts not working next.js 16"
```

**Result:**
- Next.js 16 renamed `middleware.ts` to `proxy.ts`
- Export `proxy` function instead of `middleware`
- Only for Node.js runtime (Edge unchanged)

**Fix Applied:**
- Rename `middleware.ts` → `proxy.ts`
- Change export to `proxy`

**Recorded in memory:**
```markdown
## Next.js 16
**Issue:** middleware.ts renamed to proxy.ts
**Expected:** middleware.ts to work
**Actual:** File ignored, routes not protected
**Workaround:** Rename to proxy.ts and export `proxy` not `middleware`
**Documentation:** /vercel/next.js/v16 - "middleware renamed in Node.js runtime"
**Date learned:** 2026-02-05
```

### Example 3: Playwright ECONNRESET Teardown
**Error:** ECONNRESET during test cleanup, CI fails

**Context7 Query:**
```
libraryId: "/microsoft/playwright"
query: "webServer graceful shutdown ECONNRESET prevention"
```

**Result:**
- Use `gracefulShutdown` option with SIGTERM
- Set `stderr: 'ignore'` to suppress harmless connection resets
- Give server time to close connections before SIGKILL

**Fix Applied:**
```typescript
// playwright.config.ts
webServer: {
  command: "npm run dev",
  stderr: "ignore",
  gracefulShutdown: {
    signal: "SIGTERM",
    timeout: 1000,
  },
}
```

**Recorded in memory:**
```markdown
## Playwright - ECONNRESET During Teardown
**Issue:** per-worker cleanup causes race condition with server shutdown
**Expected:** Clean test exit
**Actual:** ECONNRESET errors logged as uncaughtException, crash CI
**Workaround:** Use direct Supabase client + gracefulShutdown + stderr:'ignore'
**Documentation:** /microsoft/playwright - "webServer gracefulShutdown option"
**Date learned:** 2026-02-09
```

## Limitations

**Context7 cannot help with:**
- Project-specific business logic bugs
- Custom utility function errors
- Database/API integration issues (use actual testing)
- Configuration problems (check config files)

**Use Explore agent for:**
- Finding implementation code
- Tracing execution paths
- Searching codebase patterns
- Git history analysis

**Use Context7 for:**
- Understanding framework behavior
- Learning best practices
- Version-specific gotchas
- Official API documentation

## Cost Management

**Context7 queries cost tokens and time:**
- Each query: ~500-2000 tokens
- Response time: ~2-5 seconds

**Optimization strategies:**
1. **Check memory first** - Avoid redundant queries
2. **Use specific queries** - Get relevant results faster
3. **Record findings** - Build memory for future
4. **Only when needed** - Don't query for obvious issues

**Budget guidelines:**
- 40% of framework-related issues should use Context7
- Average 1-2 queries per complex test fix
- Most fixes should hit memory, not Context7

## Troubleshooting Context7

### Query returns no results
**Causes:**
- Library ID incorrect (typo or wrong org)
- Query too specific or obscure
- Framework doesn't document that pattern

**Solutions:**
- Try `resolve-library-id` again
- Broaden query slightly
- Check framework version (might be too new/old)

### Query returns irrelevant results
**Causes:**
- Query too broad
- Multiple meanings of term
- Framework has multiple features with similar names

**Solutions:**
- Add more context from error
- Include API names or specific terms
- Try alternative query phrasing

### Library ID not resolving
**Causes:**
- Package name differs from Context7 name
- Framework not indexed in Context7
- Typo in library name

**Solutions:**
- Try common variations (playwright vs @playwright/test)
- Check Context7 supported frameworks
- Fall back to manual docs search

## Success Criteria

**Context7 is working well when:**
- 40% of framework issues query docs
- Queries return relevant patterns 80%+ of time
- Documentation findings solve problem
- Patterns recorded in memory for reuse
- Time to fix decreases for framework issues

**Context7 needs adjustment when:**
- Queries mostly irrelevant (>70% false positives)
- Never or rarely used (<10% of issues)
- Takes longer than manual docs search
- Results don't match actual framework behavior

## Future Enhancements

**Potential improvements:**
- Auto-detect framework from error before asking
- Suggest query based on error pattern
- Cache common queries globally
- Pre-populate memory with known patterns
- Integration with framework changelogs for version gotchas
