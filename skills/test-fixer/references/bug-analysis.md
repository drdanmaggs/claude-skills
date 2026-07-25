# Root Cause Analysis: Bug vs Test Issue

**Use Opus + Sequential Thinking + Explore agent for this analysis.**

## Purpose

When a test fails consistently, determine the ROOT CAUSE:
- **Is the CODE behaving incorrectly?** (Real bug that affects production)
- **Is the TEST expecting the wrong thing?** (Test needs fixing)

This analysis happens BEFORE deciding whether to fix the test, because:
- If it's a BUG → The test is doing its job! Fix the code.
- If it's a TEST ISSUE → Then assess whether the test is worth fixing.

## When to Run This Analysis

Run this for **consistently failing tests** (not flaky) after Step 1 triage.

**Skip this for flaky tests** - they have timing/state issues, not logic bugs.

## How to Execute This Analysis

This analysis should be run in an Explore subagent with Opus model using the Task tool:

```
Task(
  subagent_type="Explore",
  model="opus",
  description="Analyze if test caught real bug",
  prompt="[Full analysis prompt - see framework below]"
)
```

The Explore agent provides:
- Glob, Grep, Read tools for codebase exploration
- No write access (read-only analysis)
- Optimized for research and investigation

## Analysis Framework (Sequential Thinking)

**Use the mcp__sequential-thinking__sequentialthinking tool** with Opus model to work through these systematically:

### Thought 0: Check Memory First (NEW)

Before deep analysis, check if this pattern has been encountered before:

```bash
# Get project hash (worktree-safe - uses git remote URL)
PROJECT_HASH=$(echo -n "$(git config --get remote.origin.url 2>/dev/null || git rev-parse --show-toplevel)" | md5sum | cut -d' ' -f1)

# Search memory for similar patterns
grep "[error keyword]" ~/.claude/skills/test-fixer/memory/$PROJECT_HASH/common-failures.md
grep "[framework]" ~/.claude/skills/test-fixer/memory/$PROJECT_HASH/framework-gotchas.md
```

**If found in memory:**
- Review past root cause determination
- Check if same "BUG IN CODE" vs "BUG IN TEST" pattern applies
- Apply known solution if applicable
- Skip to final thought with confidence

**If not found:**
- Proceed with full analysis (Thoughts 1-13)
- Record pattern after determining root cause

See [memory/README.md](../memory/README.md) for complete memory usage.

### Thought 1-3: Understand What the Test Claims

**Read the test code deeply:**

1. **What behavior does the test expect?**
   - What inputs does it provide?
   - What outputs does it expect?
   - What state changes should occur?

2. **What is the test's assumption about correctness?**
   - "Feature X should behave like Y"
   - "When user does A, system should respond with B"
   - "Edge case C should be handled by returning D"

3. **Is this expectation documented anywhere?**
   - Check requirements, tickets, comments
   - Look at related tests
   - Search for product specs or documentation

**Example:**
```typescript
test('premium users get 50% discount', () => {
  const cart = { items: [{ price: 100 }] };
  const user = { tier: 'premium' };

  expect(calculateTotal(cart, user)).toBe(50); // Expects 50% off
});
```

The test claims: "Premium users should get 50% discount on total"

### Thought 4-7: Understand What the Code Actually Does

**Use Explore agent to investigate the implementation:**

1. **Read the implementation code**
   - What does the function/component actually do?
   - How does it handle the inputs from the test?
   - What does it return?

2. **Trace the execution path**
   - Use Explore to find related functions
   - Follow the data flow
   - Identify where the mismatch occurs

3. **Check for edge case handling**
   - Does the code handle null/undefined?
   - Does it validate inputs?
   - Are there early returns or exceptions?

4. **Look for recent changes**
   ```bash
   git log --oneline -10 -- path/to/implementation.ts
   git diff HEAD~5 -- path/to/implementation.ts
   ```

**Example (continuing above):**
```typescript
function calculateTotal(cart, user) {
  const subtotal = cart.items.reduce((sum, item) => sum + item.price, 0);

  // Only 20% discount for premium users
  const discount = user.tier === 'premium' ? 0.2 : 0;

  return subtotal * (1 - discount);
}
```

The code actually implements: "Premium users get 20% discount, not 50%"

### Thought 8-10: Determine Which is Correct

**This is the critical analysis:**

1. **Check authoritative sources**
   - Product requirements documents
   - GitHub issues/tickets
   - Product manager specifications
   - User documentation
   - Marketing materials

2. **Check production behavior**
   - What does production currently do?
   - Have users reported issues?
   - Is this working as intended in prod?

3. **Check broader codebase context** (Use Explore agent)
   - Are there other tests for discounts?
   - What do they expect?
   - Is there a pattern/standard?
   - Check related files (pricing logic, user tiers, etc.)

4. **Consult framework documentation if applicable** (NEW - Use Context7)
   - If error suggests framework-specific behavior
   - Query official docs to understand expected behavior
   - See [context7-integration.md](context7-integration.md) for usage patterns

**Example Context7 usage:**

If the error involves framework behavior (e.g., "strict mode violation", "act warning", "timeout"):

```
Thought 9: Error "strict mode violation" suggests Playwright selector issue.
Need to verify expected framework behavior.

Using Context7:
- Identify framework: Playwright (from stack trace @playwright/test)
- Library ID: /microsoft/playwright
- Query: "strict mode getByRole multiple elements expected behavior"

Documentation result:
- Strict mode is intentional to prevent ambiguous selectors
- getByRole should use { name: 'text' } option when multiple elements exist
- This is not a bug - it's a quality check

Conclusion: Neither code nor test is "wrong" - test needs more specific selector.
This is a FRAMEWORK GOTCHA, not a code/test bug.
```

See [context7-integration.md](context7-integration.md) for:
- When to use Context7
- Common framework library IDs
- Query patterns
- Error pattern mapping

**Example analysis:**

Using Explore agent, search for:
- "premium discount" across codebase
- Other pricing tests
- Product configuration files

Findings:
- 5 other tests expect 20% premium discount
- `config/pricing.ts` defines `PREMIUM_DISCOUNT = 0.2`
- No mention of 50% anywhere
- Feature ticket #123 specifies "20% discount for premium tier"

**Conclusion: The test is wrong (expects 50% but should expect 20%)**

### Thought 11-13: Consider Impact and Severity

**If the CODE is wrong (real bug):**

1. **Severity assessment**
   - Does this affect production RIGHT NOW?
   - How many users are impacted?
   - Is this a security issue? Data integrity issue?
   - Financial impact?

2. **Scope assessment**
   - Is this isolated or systemic?
   - Are there other similar bugs?
   - Does this indicate a deeper architectural issue?

3. **Urgency**
   - Needs immediate hotfix?
   - Can wait for next release?
   - Should block current PR?

**If the TEST is wrong:**

1. **Why is the test wrong?**
   - Outdated after code changes?
   - Initially written incorrectly?
   - Misunderstanding of requirements?

2. **Are there other wrong tests?**
   - Check related tests
   - Same author/time period?
   - Same misunderstanding?

### Final Thought: State the Root Cause Clearly

**Template:**

```
ROOT CAUSE: [BUG IN CODE | BUG IN TEST]

Evidence:
- [List 3-5 key pieces of evidence]

Reasoning:
- [Explain the logical chain]

Recommended action:
- [Specific fix to apply]

Impact:
- [Severity and scope if code bug]
- [How to prevent if test bug]
```

## Decision Matrix

### ✅ BUG IN CODE (Test is Correct)

**All of these should be true:**
- Test expectation matches documented requirements
- Test expectation matches production behavior OR production is known to be buggy
- Multiple sources confirm test's expectation is correct
- Code demonstrably does something different than specified

**Action:**
1. **Acknowledge the test did its job** - it caught a real bug!
2. Fix the code to match the correct behavior
3. Run all tests to ensure fix doesn't break other things
4. Consider adding more tests for related edge cases
5. Document the bug in commit message

**Example commit:**
```bash
git commit -m "fix: correct premium discount from 20% to 50%

Test correctly identified that premium users should receive 50%
discount per feature spec #123, but implementation only applied 20%.

Affects all premium user purchases since v2.1.0 launch.

Fixes #456"
```

### ❌ BUG IN TEST (Code is Correct)

**All of these should be true:**
- Code behavior matches documented requirements
- Code behavior matches production (and production is working correctly)
- Multiple sources confirm code is correct
- Test expectation is demonstrably wrong

**Action:**
1. Fix the test to match correct behavior
2. Investigate if other tests have same issue
3. Document why test was wrong in commit message
4. Proceed to Step 3 (Test Value Assessment) if uncertain about test value

**Example commit:**
```bash
git commit -m "test: fix incorrect discount expectation

Test expected 50% premium discount but correct value is 20%
per pricing.ts configuration and feature spec #123.

Updated assertion to match actual correct behavior."
```

### 🔧 FRAMEWORK GOTCHA (NEW - Neither Wrong)

**Sometimes the issue is framework behavior, not code or test:**
- Test expectation is reasonable
- Code implementation is reasonable
- But framework behavior requires specific pattern

**Example:** Playwright strict mode violation - both test and code are fine, but selector needs to be more specific per framework best practices.

**Action:**
1. Apply framework-recommended pattern (from Context7)
2. Record in memory as framework gotcha
3. Document why this pattern is needed (link to Context7 docs)

**Example commit:**
```bash
git commit -m "test: use specific selector for Playwright strict mode

Playwright strict mode requires { name } option when multiple elements
match getByRole. This is working as designed per official docs.

Changed from: getByRole('button')
Changed to: getByRole('button', { name: 'Submit' })

See: /microsoft/playwright - strict mode best practices"
```

### ⚠️ BOTH ARE WRONG

**Sometimes discovered issues:**
- Test expects A
- Code does B
- Correct behavior is C

**Action:**
1. Fix the code first (higher priority)
2. Then fix the test
3. Document both issues

### 🤔 UNCERTAIN - Need More Information

**If genuinely unclear which is correct:**

**Immediate actions:**
1. **Ask the user** - they might know the requirements
2. **Check with product/business team** - what's the intended behavior?
3. **Check production data** - what are users actually experiencing?

**While waiting:**
- Document the ambiguity
- Create a GitHub issue to track investigation
- Add TODO comment in code
- Don't merge PR until resolved

## Common Patterns

### Pattern 1: Test Caught Real Bug

**Scenario:** New feature introduced logic bug

```typescript
// Code accidentally swapped comparison
function canAccessFeature(user) {
  return user.tier === 'free'; // BUG! Should be 'premium'
}

// Test correctly expects premium access
test('premium users can access feature', () => {
  expect(canAccessFeature({ tier: 'premium' })).toBe(true); // FAILS ✅
});
```

**Root cause:** BUG IN CODE - test is correctly failing

### Pattern 2: Test Didn't Update with Code

**Scenario:** Code evolved, test didn't update

```typescript
// Code changed from string to object
function getUser(id) {
  return { id, name: 'John', email: 'john@example.com' }; // Returns object now
}

// Test expects old string format
test('gets user', () => {
  expect(getUser('123')).toBe('John'); // BUG IN TEST - expects old format
});
```

**Root cause:** BUG IN TEST - code correctly evolved, test is stale

### Pattern 3: Requirements Were Wrong

**Scenario:** Original spec was incorrect

```typescript
// Code implements original spec (which was wrong)
function calculateShipping(weight) {
  return weight * 0.5; // Original spec: $0.50/lb
}

// Test catches that this doesn't match new business rules
test('shipping under 5lbs is flat $3', () => {
  expect(calculateShipping(2)).toBe(3); // FAILS - reveals spec changed
});
```

**Root cause:** BUG IN CODE - requirements changed, code needs update

### Pattern 4: Test Is Too Strict

**Scenario:** Test asserts implementation details

```typescript
function formatDate(date) {
  return date.toLocaleDateString(); // Browser-specific format
}

test('formats date', () => {
  expect(formatDate(new Date('2024-01-01'))).toBe('1/1/2024'); // BUG IN TEST - assumes US locale
});
```

**Root cause:** BUG IN TEST - test is too strict about format

## Use Explore Agent Effectively

**Key searches to run:**

1. **Find related tests:**
   ```
   Explore: "Search for all tests related to [feature/function]"
   ```

2. **Find implementation:**
   ```
   Explore: "Find the implementation of [function/feature]"
   ```

3. **Find requirements:**
   ```
   Explore: "Search for documentation, comments, or issues about [feature]"
   ```

4. **Find similar patterns:**
   ```
   Explore: "Find other places where [pattern] is used"
   ```

5. **Check history:**
   ```bash
   git log --all --oneline --grep="premium discount"
   git log --all --oneline -- path/to/related/files
   ```

## Integration with Main Workflow

```
Step 1: Fast Triage (flaky vs failing)
    ↓
    [If FAILING TEST]
    ↓
Step 2: Root Cause Analysis - Bug vs Test Issue ← YOU ARE HERE
    ↓
┌──────────────────┬────────────────┐
│ BUG IN CODE      │ BUG IN TEST    │
│                  │                │
│ Fix the code     │ Fix the test   │
│ Test wins! ✅    │ Then assess    │
│                  │ test value     │
│                  │ (Step 3)       │
└──────────────────┴────────────────┘
```

## Key Principles

1. **Tests that catch bugs are VALUABLE** - even if they're flaky or poorly written, they found something real

2. **Use authoritative sources** - requirements docs, tickets, production behavior, other tests

3. **Think like a detective** - gather evidence, form hypothesis, test it

4. **When in doubt, ask** - unclear requirements should be resolved, not guessed

5. **Document your reasoning** - future developers need to understand WHY the fix was made

## Examples Using Sequential Thinking

### Example 1: Real Bug Found

**Test failure:**
```
Expected: user.canDelete to be true
Received: false
```

**Sequential thinking process:**

**Thought 1:** Test expects admin users can delete posts. Looking at test:
```typescript
test('admin can delete posts', () => {
  const admin = { role: 'admin', permissions: ['read', 'write', 'delete'] };
  expect(canDeletePost(admin, post)).toBe(true);
});
```

**Thought 2:** Test assumption: Users with 'admin' role AND 'delete' permission should be able to delete.

**Thought 3:** Looking at implementation:
```typescript
function canDeletePost(user, post) {
  return user.role === 'admin'; // BUG: Ignores permissions array!
}
```

**Thought 4:** Code only checks role, completely ignores permissions array.

**Thought 5:** Using Explore to search "permissions" - found:
- `docs/rbac.md` specifies "Role AND permissions must both be checked"
- 10 other functions correctly check both role and permissions
- Feature ticket #789 explicitly requires permission checking

**Thought 6:** Production likely has a security bug - admins without delete permission can still delete!

**Thought 7:** This is a REAL BUG. Test is correct, code is wrong.

**ROOT CAUSE: BUG IN CODE**

Evidence:
- Documentation specifies checking both role and permissions
- 10 other similar functions do it correctly
- Feature ticket requires permission checking
- This is a security issue in production

Recommended action:
- Fix canDeletePost to check both role AND permissions
- Add regression tests for permission denial cases
- Security review: are there other functions with same bug?

Impact:
- HIGH severity - security bug affecting authorization
- Currently in production
- All admin operations should be audited

### Example 2: Stale Test

**Test failure:**
```
Expected: response status to be 200
Received: 201
```

**Sequential thinking process:**

**Thought 1:** Test expects 200 OK when creating a user:
```typescript
test('creates user', async () => {
  const response = await api.post('/users', userData);
  expect(response.status).toBe(200);
});
```

**Thought 2:** Test assumes successful creation returns 200.

**Thought 3:** Looking at implementation:
```typescript
app.post('/users', async (req, res) => {
  const user = await createUser(req.body);
  res.status(201).json(user); // Returns 201 Created
});
```

**Thought 4:** Code returns 201 Created, which is correct HTTP semantics for resource creation.

**Thought 5:** Checking git history:
```bash
commit abc123 (3 months ago)
"refactor: fix HTTP status codes to match REST conventions"
```

**Thought 6:** Using Explore to search for other POST endpoints - ALL return 201 for creation.

**Thought 7:** REST standard specifies 201 Created for successful resource creation. Code is correct, test is outdated.

**ROOT CAUSE: BUG IN TEST**

Evidence:
- HTTP standard specifies 201 for resource creation
- Code was intentionally updated 3 months ago to fix this
- All other POST endpoints correctly return 201
- Test expects incorrect status code

Recommended action:
- Update test to expect 201 instead of 200
- Check for other tests expecting wrong HTTP codes
- No production impact - this was fixed correctly

Impact:
- None - test is simply stale from refactoring
