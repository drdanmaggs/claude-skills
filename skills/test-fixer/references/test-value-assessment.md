# Test Value Assessment

**Use Opus + Sequential Thinking for this analysis.**

## Purpose

Before investing time fixing a failing or flaky test, determine if it's actually worth keeping. AI-generated tests often include meaningless assertions or test implementation details rather than behavior.

## When to Run This Assessment

Run AFTER Step 2 (Root Cause Analysis - only if test is wrong, not if code has a bug) but BEFORE diving into fix workflow.

## Assessment Questions (Sequential Thinking)

Use Sequential Thinking to reason through these systematically:

### 1. What Does This Test Actually Verify?

Read the test code and reason:
- What behavior or outcome is being verified?
- What would break if this test didn't exist?
- Does it test a meaningful user-facing behavior or business rule?

**Red flags:**
```typescript
// ❌ Tests implementation detail
expect(component.state.internalFlag).toBe(true);

// ❌ Trivial assertion
expect(user.id).toBeDefined();

// ❌ Tautology (tests nothing)
expect(getValue()).toBe(getValue());

// ❌ Mock testing mock
expect(mockFn).toHaveBeenCalled(); // But doesn't verify outcome
```

**Good signals:**
```typescript
// ✅ Tests behavior
expect(submitButton).toBeDisabled();
expect(errorMessage).toContain('Invalid email');

// ✅ Tests business rule
expect(calculateTotal(cart)).toBe(42.99);

// ✅ Tests integration
expect(await api.getUser('123')).toMatchObject({ name: 'John' });
```

### 2. Is This Test Redundant?

Check if other tests already cover this:
- Search for similar tests in the same file
- Check if integration tests already cover this unit test's scenario
- Is this a "kitchen sink" test that combines multiple scenarios poorly?

**If redundant:** Other tests already protect against regression → Safe to delete

### 3. Does This Test Guide Implementation?

Consider TDD value:
- Would this test help a developer understand the feature?
- Does it document important edge cases or requirements?
- Or is it just noise that makes the test suite harder to maintain?

**If noise:** Deleting improves test suite quality → Delete it

### 4. What's the Cost/Benefit?

Reason through trade-offs:
- **Cost to fix:** Time to debug, stabilize, maintain
- **Cost to delete:** Risk of losing coverage (if meaningful)
- **Benefit of keeping:** Protection against real regressions
- **Benefit of deleting:** Cleaner suite, faster CI, less maintenance

### 5. Historical Context

Check git history:
```bash
git log --oneline path/to/test.spec.ts
git blame path/to/test.spec.ts | grep "test("
```

Questions:
- Was this added by AI in a bulk generation?
- Did it ever catch a real bug?
- Has it been flaky since creation?
- Does the feature it tests still exist?

## Decision Matrix

### ✅ KEEP AND FIX

**All of these should be true:**
- Tests meaningful behavior (not implementation details)
- Not redundant with other tests
- Would catch real regressions if removed
- Helps document requirements or edge cases

**Action:** Proceed to fix workflow (Step 4/5)

### ❌ DELETE

**Any of these is sufficient to delete:**
- Tests nothing meaningful (trivial assertions, tautologies)
- Tests implementation details that could change
- Completely redundant with existing tests
- Tests a feature that no longer exists
- AI-generated noise with no actual value
- Cost to maintain >> benefit of keeping

**Action:**
1. Delete the test
2. Run test suite to confirm no critical coverage lost
3. Commit deletion with explanation:
   ```bash
   git rm path/to/test.spec.ts
   # OR remove specific test from file

   git commit -m "test: remove meaningless test

   Test verified [implementation detail / trivial assertion /
   redundant scenario] rather than meaningful behavior.

   Coverage maintained by [list other tests that cover this]."
   ```

### ⚠️ UNCERTAIN?

**If genuinely unsure:**
- Bias toward keeping if test touches critical paths (auth, payments, data integrity)
- Bias toward deleting if test is clearly flaky with unclear value
- Ask: "Would I write this test today knowing what I know now?"

## Example Analyses

### Example 1: DELETE - Trivial Assertion

```typescript
test('user has id', async () => {
  const user = await createUser({ name: 'John' });
  expect(user.id).toBeDefined();
});
```

**Sequential reasoning:**
- What does it verify? That database auto-generates IDs
- What would break? Nothing - this is infrastructure, not business logic
- Is it redundant? Every other test assumes IDs exist
- Does it guide implementation? No
- **Decision: DELETE** - trivial assertion, no value

### Example 2: KEEP - Meaningful Business Rule

```typescript
test('free tier users cannot create more than 5 projects', async () => {
  const user = await createUser({ tier: 'free' });
  await createProjects(user, 5);

  await expect(createProject(user, 'Project 6'))
    .rejects.toThrow('Project limit reached');
});
```

**Sequential reasoning:**
- What does it verify? Core business rule (tier limits)
- What would break? We could accidentally allow unlimited free projects
- Is it redundant? No other test verifies this limit
- Does it guide implementation? Yes - documents the rule clearly
- **Decision: KEEP** - valuable business logic test

### Example 3: DELETE - Testing Mocks

```typescript
test('calls fetchUser when mounting', () => {
  const mockFetch = vi.fn();
  render(<UserProfile fetchUser={mockFetch} />);

  expect(mockFetch).toHaveBeenCalledOnce();
});
```

**Sequential reasoning:**
- What does it verify? That component calls prop function
- What would break? Nothing user-facing - implementation detail
- Is it redundant? Integration test likely covers actual user loading
- Does it guide implementation? No - tests HOW not WHAT
- **Decision: DELETE** - tests implementation, not behavior

### Example 4: KEEP - Integration Test with Real Value

```typescript
test('user can submit form and see success message', async () => {
  render(<ContactForm />);

  await userEvent.type(screen.getByLabelText('Email'), 'john@example.com');
  await userEvent.type(screen.getByLabelText('Message'), 'Hello');
  await userEvent.click(screen.getByRole('button', { name: 'Submit' }));

  await waitFor(() => {
    expect(screen.getByText('Message sent!')).toBeInTheDocument();
  });
});
```

**Sequential reasoning:**
- What does it verify? Critical user flow end-to-end
- What would break? Users couldn't submit forms
- Is it redundant? No - this is the primary form submission flow
- Does it guide implementation? Yes - shows expected UX
- **Decision: KEEP** - valuable integration test

## Integration with Main Workflow

```
Step 1: Fast Triage (flaky vs failing)
    ↓
Step 2: Root Cause Analysis (bug in code vs test?)
    ↓
    [If BUG IN TEST]
    ↓
Step 3: Test Value Assessment ← YOU ARE HERE
    ↓
┌────────────────┬──────────────┐
│ KEEP AND FIX   │ DELETE       │
│                │              │
│ Proceed to     │ Remove test  │
│ Step 4/5       │ Commit       │
│ (fix workflow) │ Done         │
└────────────────┴──────────────┘
```

## Key Principle

**Don't fix garbage tests just because they exist.** AI can generate tests faster than humans can fix them. Be ruthless about deleting low-value tests - it improves the test suite overall.
