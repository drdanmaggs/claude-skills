# Sequential Thinking Prompts for Test Debugging

## Purpose

This file provides **copy-paste templates** for using the `mcp__sequential-thinking__sequentialthinking` tool in each workflow step.

Each template includes:
- Thought breakdown (how many thoughts, what each covers)
- Integration points for Context7 and Explore
- Output format expectations

---

## Step 2: Root Cause Analysis Template

```markdown
Use Sequential Thinking (mcp__sequential-thinking__sequentialthinking) to determine if test caught bug or if test is wrong.

CONTEXT:
- Test failure: [paste full error]
- Test file: [absolute path]
- Project: [project name]

ESTIMATED THOUGHTS: 12-15

PROCESS:

**Thoughts 1-3: Understand Test Expectation**
1. Read test code at [path]
2. Identify what behavior test expects
3. Document test's assumptions

**Thoughts 4-7: Understand Code Behavior**
4. Use Explore to find implementation
5. Read implementation code
6. Trace execution path
7. Identify mismatch point

**Thought 8: Check Memory**
8. Review memory/[project-hash]/ for similar patterns
   - If found: Use past solution
   - If not found: Continue analysis

**Thought 9-10: Consult Documentation (if needed)**
9. If error suggests framework issue, use Context7:
   - Identify framework from stack trace
   - Query: "[framework] [error pattern] expected behavior"
10. Apply documentation knowledge to analysis

**Thoughts 11-13: Determine Correctness**
11. Check requirements, other tests, production behavior
12. Which is correct: test or code?
13. Gather evidence for determination

**Thought 14: State Root Cause**
Format:
```
ROOT CAUSE: [BUG IN CODE | BUG IN TEST | FRAMEWORK GOTCHA]

Evidence:
- [3-5 key pieces]

Reasoning:
- [Logical chain]

Recommended action:
- [Specific fix]

Context7 findings (if used):
- [Documentation that informed decision]

Record in memory:
- [Yes/No - is this a novel pattern?]
```

**Thought 15: Record Pattern (if novel)**
If this is a new pattern, draft memory entry:
```markdown
## [Error Category]
**Pattern:** [Description]
**Cause:** [Root cause]
**Fix:** [Solution]
**Date:** [Today]
```
```

---

## Step 2: Detailed Example

**Scenario:** Playwright test fails with "strict mode violation"

```markdown
Use Sequential Thinking to analyze root cause.

CONTEXT:
- Test failure: "Error: strict mode violation: locator.click resolved to 3 elements"
- Test file: tests/e2e/admin-category-management.spec.ts
- Project: family-meal-planner-v3

ESTIMATED THOUGHTS: 13

---

**Thought 1:** Reading test code at tests/e2e/admin-category-management.spec.ts

The test:
```typescript
test('should add new category', async ({ page }) => {
  await page.goto('/admin/category-management');
  await page.getByRole('button').click(); // Line that fails
});
```

Test expects: Clicking a button should work
Assumption: There's only one button on the page

---

**Thought 2:** Understanding the error message

"strict mode violation: locator.click resolved to 3 elements"
- Playwright found 3 buttons
- Strict mode requires unique selectors
- Test assumption violated: multiple buttons exist

---

**Thought 3:** What does the test actually test?

Looking at test name and context:
- "should add new category"
- Likely wants to click "Add Category" button specifically
- But selector `getByRole('button')` is too broad

Test expectation unclear: which button should be clicked?

---

**Thought 4:** Using Explore to find the page implementation

Searching for admin-category-management page component...
Found: app/(admin)/admin/category-management/page.tsx

---

**Thought 5:** Reading page implementation

The page has:
- "Add Category" button (primary action)
- "Add Subcategory" button (secondary action)
- Action dropdown buttons for each item (many)

Total: 3+ buttons on page, confirming error message.

---

**Thought 6:** Tracing execution path

User flow:
1. Navigate to /admin/category-management
2. See multiple buttons
3. Test tries to click first button in DOM order
4. Playwright rejects: ambiguous selector

Issue: Test doesn't specify which button.

---

**Thought 7:** Identifying mismatch

Test assumes: One button on page
Reality: Multiple buttons (Add Category, Add Subcategory, actions)

Mismatch is in test's assumptions.

---

**Thought 8:** Checking memory

Searching memory/abc123def456/common-failures.md for "strict mode"...

Found pattern:
```
## Playwright - Strict Mode Violation
**Fix:** Add { name: 'specific text' } to disambiguate
**Occurrences:** 2
```

Known pattern! Solution: Use { name } option.

---

**Thought 9:** Consulting Context7 to verify best practice

Using mcp__context7__query-docs:
- libraryId: "/microsoft/playwright"
- query: "strict mode getByRole multiple elements handling"

Result: Documentation confirms:
- Strict mode prevents ambiguous selectors (intentional)
- Use `{ name: 'text' }` to disambiguate
- Or use `.first()` if order matters

This is working as designed, not a Playwright bug.

---

**Thought 10:** Applying documentation knowledge

Playwright expects explicit selectors for:
- Better test reliability
- Clear test intent
- Catch UI changes that add/remove elements

Test should specify which button by its accessible name.

---

**Thought 11:** Checking requirements

Looking for what the test should do:
- Test name: "should add new category"
- Intent: Click the "Add Category" button specifically
- No ambiguity in requirements

Requirements are clear: add category, not subcategory.

---

**Thought 12:** Determining correctness

Is code wrong?
- No. Page correctly has multiple buttons.
- UI design is reasonable.

Is test wrong?
- Yes. Test selector is too broad.
- Should specify "Add Category" button.

---

**Thought 13:** Gathering evidence

Evidence test is wrong:
1. Error shows 3 elements, not a crash or wrong behavior
2. Page implementation shows legitimate multiple buttons
3. Playwright docs say strict mode is intentional quality check
4. Test name implies specific button ("add category")
5. Memory shows this pattern seen before (common issue)

Confidence: High

---

**Thought 14:** Stating root cause

ROOT CAUSE: BUG IN TEST

Evidence:
- Playwright found 3 buttons (all legitimate UI elements)
- Test uses ambiguous selector getByRole('button')
- Test name implies specific button: "Add Category"
- Playwright strict mode working as designed
- Documentation confirms this is a test quality issue

Reasoning:
- Test assumption (one button) doesn't match reality (multiple buttons)
- Page design is correct (multiple actions available)
- Test needs to be more specific about which button
- Strict mode caught legitimate test quality issue

Recommended action:
Fix test selector:
```typescript
await page.getByRole('button', { name: 'Add Category' }).click();
```

Context7 findings:
- Strict mode is intentional for test quality
- { name } option is the recommended solution
- This pattern prevents flaky tests from DOM order changes

Record in memory:
- Yes, increment occurrence count (now 3 times)
- Update "Last seen" to today

---

**Thought 15:** Recording pattern update

Update memory/abc123def456/common-failures.md:

```markdown
## Playwright - Strict Mode Selector Ambiguity
**Pattern:** getByRole resolves to multiple elements
**Cause:** Selector too broad without { name } option
**Fix:** Add { name: 'specific text' } to disambiguate
**Frequency:** Common
**First seen:** 2026-01-15
**Last seen:** 2026-02-09  ← Updated
**Occurrences:** 3  ← Incremented

**Example:**
Test file: tests/e2e/admin-category-management.spec.ts
Error: "strict mode violation: getByRole('button') resolved to 3 elements"
Fix: await page.getByRole('button', { name: 'Add Category' }).click()
```

Analysis complete. Proceed to fix.
```

---

## Step 3: Test Value Assessment Template

```markdown
Use Sequential Thinking (mcp__sequential-thinking__sequentialthinking) to determine if test is worth fixing.

CONTEXT:
- Test: [test name]
- File: [path]
- Error: [brief description]

ESTIMATED THOUGHTS: 8-10

PROCESS:

**Thought 1: What does test verify?**
- Read test code
- Identify assertion and expected behavior
- Meaningful vs trivial?

**Thought 2: Is it redundant?**
- Search for similar tests in file/directory
- Check integration tests that might cover this
- Unique coverage?

**Thought 3: Check history**
```bash
git log --oneline -- [test file]
git blame [test file] | grep "test("
```
- When added (recent AI generation or long-standing)?
- Has it ever caught bugs?
- Flaky since creation?

**Thought 4: Consider test type**
- Unit: tests pure logic?
- Integration: tests real behavior?
- E2E: tests user flow?
- Does type match what's being tested?

**Thoughts 5-7: Cost/Benefit Analysis**
5. Cost to fix: [time estimate based on complexity]
6. Cost to delete: [risk of losing meaningful coverage]
7. Net value: Keep or delete?

**Thought 8: Check against project testing standards**
- Review project's CLAUDE.md or docs/testing.md
- Does this align with coverage goals?
- TDD value: would you write this today?

**Thought 9: Make decision**
Format:
```
DECISION: [KEEP AND FIX | DELETE]

Reasoning:
- [2-3 key points]

If DELETE:
- Coverage maintained by: [list other tests]
- Commit message: [suggested text]

If KEEP:
- Value proposition: [why worth fixing]
- Proceed to: [Step 4 or 5]
```

**Thought 10: Record if deletion (pattern learning)**
If deleting, note why for future reference:
```markdown
# memory/[project-hash]/test-fixes.md
## [Date] - DELETED: [test name]
**Reason:** [Trivial|Redundant|Stale|Implementation detail]
**Coverage:** [How coverage is maintained]
**Lesson:** [What to avoid in future test generation]
```
```

---

## Step 3: Detailed Example

**Scenario:** Unit test fails, questionable value

```markdown
Use Sequential Thinking to assess test value.

CONTEXT:
- Test: "should return formatted user name"
- File: lib/utils/format-user-name.test.ts
- Error: "Expected 'John Doe' but received 'JohnDoe'"

ESTIMATED THOUGHTS: 9

---

**Thought 1:** Reading test code to understand what it verifies

```typescript
test('should return formatted user name', () => {
  const result = formatUserName('John', 'Doe');
  expect(result).toBe('John Doe');
});
```

This test verifies: formatUserName adds space between first and last name

Is this meaningful?
- Yes, name formatting has business logic (spacing)
- Not trivial: could be 'John Doe' or 'JohnDoe' or 'Doe, John'

---

**Thought 2:** Checking for redundancy

Searching for similar tests in file...

Found:
```typescript
test('should handle empty last name', () => {
  expect(formatUserName('John', '')).toBe('John');
});

test('should handle special characters', () => {
  expect(formatUserName("O'Brien", 'Smith')).toBe("O'Brien Smith");
});
```

These test edge cases, but this test is the only one for normal case.

Checking integration tests...
No integration tests directly call formatUserName - it's a utility.

Unique coverage: Yes, this is the main happy path test.

---

**Thought 3:** Checking test history

```bash
git log --oneline -- lib/utils/format-user-name.test.ts
```

Result:
- f3a2b1c feat: add user name formatting
- 8d4e3c2 fix: handle empty last name edge case
- a1b2c3d fix: preserve special characters in names

git blame shows:
- Test added 3 months ago with feature
- Has been updated twice for bugs
- Caught real issues: empty names, special chars

History shows: Test has value, caught 2 bugs.

---

**Thought 4:** Analyzing test type appropriateness

Type: Unit test
What it tests: Pure function (string in, string out)
No side effects, no external dependencies.

Is unit test appropriate? Yes.
- Pure function = unit test is correct level
- Fast, deterministic, no mocks needed
- Would be wasteful as integration/E2E test

Test type matches testing need perfectly.

---

**Thought 5:** Estimating cost to fix

Looking at error: "Expected 'John Doe' but received 'JohnDoe'"

Cause: Implementation likely missing space
Fix: Add space in implementation

Estimated time: 2 minutes
- Change one line in formatUserName
- Re-run test
- Done

Cost to fix: Very low

---

**Thought 6:** Estimating cost to delete

If deleted:
- Lose test for main happy path
- Edge case tests remain, but no normal case verification
- Future refactors might break basic formatting

Risk: Medium
- Happy path is critical (most common case)
- No integration tests exercise this function
- Easy to break without noticing

Cost to delete: Medium risk to coverage

---

**Thought 7:** Net value calculation

Cost to fix: 2 minutes (very low)
Cost to delete: Medium risk (lose happy path coverage)

Net value: Fix is much cheaper than delete

Also: Test has proven value (caught 2 bugs historically)

Decision leaning: Keep and fix

---

**Thought 8:** Checking against project standards

Reading project's CLAUDE.md:

"Every code change includes tests. No exceptions unless I say otherwise."
"Stack: Vitest for unit and integration tests"

This aligns with project standards:
- Unit test for utility function
- Vitest usage correct
- Follows TDD philosophy

TDD question: Would I write this test today?
- Yes. Before writing formatUserName, would write this test first.
- Documents expected behavior clearly.
- Fast feedback on basic functionality.

Passes standards check.

---

**Thought 9:** Making decision

DECISION: KEEP AND FIX

Reasoning:
1. Test provides unique coverage for happy path
2. Has proven value (caught 2 bugs in 3 months)
3. Fix is trivial (2 minutes)
4. Deletion would reduce coverage meaningfully
5. Aligns with project TDD standards
6. Would write this test today if starting fresh

Value proposition:
- Happy path coverage is critical
- Test is fast, clear, maintainable
- Historical evidence of bug detection
- Meets TDD standard: test first, then implementation

Proceed to: Step 4 (Failing Test Workflow)

Next action: Fix formatUserName implementation to add space between names

---

No deletion record needed (test kept).
```

---

## General Sequential Thinking Tips

### Thought Number Estimation
- Simple issues: 5-8 thoughts
- Medium complexity: 8-12 thoughts
- Complex issues: 12-20 thoughts
- **Adjust `totalThoughts` as you go** - it's an estimate

### When to Branch
Use `branchFromThought` when:
- Hypothesis proves wrong, need to try different approach
- Multiple possible causes need parallel exploration
- Framework docs reveal unexpected behavior

### When to Revise
Use `isRevision: true` when:
- Earlier thought had incorrect assumption
- New evidence contradicts previous reasoning
- Context7/Explore revealed different information

### Output Format
**Every final thought should include:**
```
CONCLUSION: [Clear statement]

EVIDENCE:
- [Supporting points]

ACTION:
- [Next steps]

MEMORY UPDATE:
- [What to record, if anything]
```

### Integration Points

**Context7:**
- Call within thought when framework knowledge needed
- Record query and findings in thought
- Reference in final conclusion

**Explore:**
- Use for finding code, history, patterns
- Multi-file investigation within single thought
- Document findings inline

**Memory:**
- Check early (thought 1-2)
- Record late (final thought)
- Update incrementally if long analysis

---

## Tool Usage Within Sequential Thinking

### mcp__context7__query-docs

**When to use:** Framework behavior unclear from error/code

**In thought:**
```
Thought 7: Need to verify Playwright's expected behavior

Using Context7:
- Library: /microsoft/playwright
- Query: "waitForSelector vs waitForLoadState difference"
- Result: waitForLoadState waits for network events, waitForSelector waits for element
- Conclusion: Test should use waitForLoadState for page load, then waitForSelector

This explains the timeout - test waited for element before page finished loading.
```

### Explore Agent Tools (Glob, Grep, Read)

**When to use:** Need to search codebase

**In thought:**
```
Thought 4: Finding implementation of validateInput

Using Glob: lib/**/*validation*.ts
Found: lib/utils/validation.ts, lib/forms/validate-input.ts

Using Grep: "function validateInput" in lib/
Found: lib/forms/validate-input.ts:42

Reading lib/forms/validate-input.ts...
```

### Git Commands

**When to use:** Understanding when code changed

**In thought:**
```
Thought 8: Checking when this broke

git log --oneline -- path/to/test.spec.ts
- Last change: 2 weeks ago, "feat: add validation"

git diff HEAD~5 -- path/to/implementation.ts
- Added new required parameter 3 days ago
- Test not updated to match

Recent change likely caused failure.
```

---

## Thought Structure Best Practices

### Good Thought Structure
```
Thought 5: [Clear topic/question]

[Investigation using tools]
- Tool result 1
- Tool result 2

[Analysis of findings]
- What this means
- How it relates to error

[Conclusion for this thought]
- Key insight
- Leads to next thought
```

### Bad Thought Structure
```
Thought 5: Checking stuff

Found some things. Code looks weird. Not sure what's happening.

[Too vague, no clear findings or conclusion]
```

### Progressive Disclosure
- Early thoughts: Broad understanding
- Middle thoughts: Narrow investigation
- Late thoughts: Synthesis and decision

### Evidence Chain
Each thought should build on previous:
```
Thought 1: Test expects X
Thought 2: Code does Y
Thought 3: Y ≠ X because [reason]
Thought 4: [Reason] is caused by [root cause]
Thought 5: Fix [root cause] by [solution]
```

---

## Common Pitfalls

### Pitfall 1: Jumping to Conclusions
**Bad:**
```
Thought 1: Error says "undefined"
Conclusion: Variable not initialized
```

**Good:**
```
Thought 1: Error says "undefined"
Need to find which variable and why

Thought 2: Reading code at error line
Variable 'user' is undefined

Thought 3: Tracing where 'user' comes from
Comes from API response

Thought 4: Checking API response shape
API changed, now returns 'profile' not 'user'

Conclusion: API contract changed, test needs update
```

### Pitfall 2: Not Using Available Tools
**Bad:**
```
Thought 3: Not sure what the implementation does
Guessing it returns null?
```

**Good:**
```
Thought 3: Need to understand implementation

Using Grep to find function...
Found at lib/api/users.ts:42

Reading lib/api/users.ts...
Function returns Promise<User | null>

Now I understand: returns null when user not found
```

### Pitfall 3: Ignoring Memory
**Bad:**
```
[Starts analysis without checking memory]
[Spends 10 thoughts figuring out solution]
[Solution is already documented in memory]
```

**Good:**
```
Thought 1: Checking memory for similar patterns

grep "timeout waiting" memory/abc123/common-failures.md
Found: Playwright timeout → use waitForLoadState

Applying known solution from memory...
```

### Pitfall 4: Vague Conclusions
**Bad:**
```
Final Thought: Test is broken, need to fix it somehow
```

**Good:**
```
Final Thought:

ROOT CAUSE: Bug in test - incorrect assertion

Evidence:
- Code returns User object with 'username' field
- Test asserts 'user.name' which doesn't exist
- API docs confirm field name is 'username'

Fix: Change test from user.name to user.username

Record: No, obvious typo, not a pattern
```

---

## When to Skip Sequential Thinking

**Don't use ST for:**
- Obvious typos (can see fix immediately)
- Simple syntax errors (error message is clear)
- Issues found in memory (apply known solution)
- Trivial test failures (one-line fix)

**Do use ST for:**
- Unclear if code or test is wrong
- Multiple possible root causes
- Framework behavior unclear
- Complex interactions between components
- Decision requires weighing trade-offs

---

## Success Metrics

**ST is working well when:**
- Root cause determination is clear and confident
- Evidence chain is logical and complete
- Recommended actions are specific
- Fewer "guess and check" iterations
- Patterns recorded for future use

**ST needs adjustment when:**
- Thoughts are too granular (20+ thoughts for simple issue)
- Conclusions are vague or uncertain
- Not using available tools
- Jumping to conclusions without evidence
- Forgetting to check memory first
