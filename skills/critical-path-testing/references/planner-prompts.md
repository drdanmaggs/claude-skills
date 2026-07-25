# Planner Prompts

**Purpose:** Sonnet planner templates for Phase 1.1

**Agent:** Sonnet (understanding criticality requires reasoning)

---

## Base Planner Prompt Template

````markdown
You are a test planner analyzing a critical file for production-ready test generation.

**Your task:**

1. Read the file and understand what makes it CRITICAL (not just what it does)
2. Identify known failure modes from test-fixer memory
3. Determine integration requirements (DB, external API, auth)
4. Plan specific test cases that matter for THIS domain
5. Assess complexity to recommend the right model (Haiku vs Sonnet)

**File to analyze:** {file_path}

**Criticality score:** {criticality_score}

**Criticality breakdown:**

- Domain category: {domain_category} ({category_points} points)
- Risk indicators: {risk_details}
- Impact radius: {impact_details}
- Test gap: {test_gap_details}

**Test-fixer memory insights:**
{memory_insights}

**Session constants:**
{session_constants}

---

## Analysis Framework

### 1. What's Critical About This File?

Consider the domain:

- **Authentication?** Test concurrent sessions, rate limiting, session invalidation
- **Payments?** Test idempotency, partial failures, refunds
- **Data integrity?** Test cascades, FK constraints, RLS policies
- **API routes?** Test auth, input validation, error handling

**Question to answer:** If this code fails in production, what's the blast radius?

### 2. Known Failure Modes

Check test-fixer memory for:

- Has this file appeared in failure logs?
- Similar files that had issues?
- Common patterns (CASCADE DELETE, rate limiting, etc.)?

**Extract:** List of failure modes to test for

### 3. Integration Requirements

Determine test type:

- **Unit:** Pure functions, no I/O
- **Integration:** DB operations, Supabase calls
- **E2E:** Full user flows, browser automation

**Check dependencies:**

- Supabase client → Integration test
- External APIs → Integration test with mocks
- Server actions → Extract logic, test logic function
- React components → E2E test (unless pure)

### 4. Test Cases That Matter

NOT generic "should work" tests. Specific edge cases for THIS domain:

**Authentication example:**

- ✅ "should handle concurrent login attempts without race conditions"
- ✅ "should invalidate all sessions when password changes"
- ❌ "should login successfully" (too generic)

**Payment example:**

- ✅ "should prevent duplicate charges via idempotency key"
- ✅ "should handle partial refunds correctly"
- ❌ "should process payment" (too generic)

**Prioritize:**

- HIGH: Failure modes from memory, security-critical, data integrity
- MEDIUM: Edge cases, error handling
- LOW: Happy path (still include, but after critical tests)

### 5. Complexity Assessment

**Route to Sonnet if:**

- High criticality score (≥80)
- Complex state machines
- Multiple external dependencies
- Auth/payment critical paths

**Route to Haiku if:**

- Medium criticality (60-79)
- Simple CRUD operations
- Utilities (with context from planner)

**Default:** If uncertain, recommend Sonnet (safer for critical paths)

---

## Output Format

Return JSON:

```json
{
  "file": "{file_path}",
  "criticality": "{authentication-core|payment-processing|data-integrity|api-route|business-logic|utility}",
  "known_failure_modes": [
    "Rate limiting during parallel auth operations",
    "CASCADE DELETE race condition in related tables"
  ],
  "test_strategy": "{integration|unit|e2e}",
  "complexity": "{high|medium|low}",
  "test_cases": [
    {
      "name": "should handle concurrent login attempts without race conditions",
      "priority": "HIGH",
      "pattern": "worker_fixtures_with_retry",
      "rationale": "Auth critical, known failure mode from memory"
    },
    {
      "name": "should invalidate all sessions when password changes",
      "priority": "HIGH",
      "pattern": "cascade_verification",
      "rationale": "Security requirement, CASCADE DELETE edge case"
    },
    {
      "name": "should enforce rate limiting correctly",
      "priority": "MEDIUM",
      "pattern": "retry_logic",
      "rationale": "Known failure mode, CI reliability"
    }
  ],
  "required_fixtures": ["workerHousehold", "multipleUsers"],
  "external_dependencies": ["supabase_auth_api"],
  "recommended_model": "sonnet",
  "rationale": "High criticality (score 100), authentication core, complex state management with known failure modes"
}
```
````

**Patterns reference:**

- `worker_fixtures` → Standard worker-scoped fixture usage
- `worker_fixtures_with_retry` → Worker fixtures + exponential backoff retry
- `cascade_verification` → Manual child-first deletion, verify CASCADE behavior
- `retry_logic` → Exponential backoff for external service calls
- `error_checking` → Explicit error assertions on all DB ops
- `hydration_wait` → E2E React hydration handling

---

## Example Plans

### Example 1: Authentication (High Criticality)

**File:** `lib/auth/login-logic.ts`
**Score:** 100

```json
{
  "file": "lib/auth/login-logic.ts",
  "criticality": "authentication-core",
  "known_failure_modes": [
    "Supabase auth rate limiting during parallel test runs",
    "Concurrent session creation race conditions"
  ],
  "test_strategy": "integration",
  "complexity": "high",
  "test_cases": [
    {
      "name": "should handle concurrent login attempts without race conditions",
      "priority": "HIGH",
      "pattern": "worker_fixtures_with_retry",
      "rationale": "Core auth flow, known rate limiting issue"
    },
    {
      "name": "should create session with correct household association",
      "priority": "HIGH",
      "pattern": "worker_fixtures",
      "rationale": "Data integrity critical for multi-tenant system"
    },
    {
      "name": "should reject invalid credentials",
      "priority": "HIGH",
      "pattern": "error_checking",
      "rationale": "Security requirement"
    },
    {
      "name": "should prevent brute force with rate limiting",
      "priority": "MEDIUM",
      "pattern": "retry_logic",
      "rationale": "Security hardening"
    }
  ],
  "required_fixtures": ["workerHousehold"],
  "external_dependencies": ["supabase_auth_api"],
  "recommended_model": "sonnet",
  "rationale": "Authentication core, high criticality, complex error handling, known failure modes"
}
```

### Example 2: Payment Processing (High Criticality)

**File:** `lib/payments/process-payment-logic.ts`
**Score:** 95

```json
{
  "file": "lib/payments/process-payment-logic.ts",
  "criticality": "payment-processing",
  "known_failure_modes": [
    "Race condition in idempotency check",
    "Partial failures leaving inconsistent state"
  ],
  "test_strategy": "integration",
  "complexity": "high",
  "test_cases": [
    {
      "name": "should prevent duplicate charges via idempotency key",
      "priority": "HIGH",
      "pattern": "worker_fixtures",
      "rationale": "Critical for payment integrity, known race condition"
    },
    {
      "name": "should handle Stripe API failures gracefully",
      "priority": "HIGH",
      "pattern": "error_checking",
      "rationale": "External dependency failure mode"
    },
    {
      "name": "should rollback DB changes on payment failure",
      "priority": "HIGH",
      "pattern": "cascade_verification",
      "rationale": "Data consistency requirement"
    },
    {
      "name": "should create correct audit trail",
      "priority": "MEDIUM",
      "pattern": "worker_fixtures",
      "rationale": "Compliance requirement"
    }
  ],
  "required_fixtures": ["workerHousehold", "stripeMock"],
  "external_dependencies": ["stripe_api"],
  "recommended_model": "sonnet",
  "rationale": "Payment critical, complex transaction logic, multiple failure modes"
}
```

### Example 3: Utility Function (Low Criticality)

**File:** `lib/utils/format-date.ts`
**Score:** 20

```json
{
  "file": "lib/utils/format-date.ts",
  "criticality": "utility",
  "known_failure_modes": [],
  "test_strategy": "unit",
  "complexity": "low",
  "test_cases": [
    {
      "name": "should format date in correct timezone",
      "priority": "MEDIUM",
      "pattern": "none",
      "rationale": "Edge case for international users"
    },
    {
      "name": "should handle invalid dates",
      "priority": "LOW",
      "pattern": "error_checking",
      "rationale": "Defensive programming"
    }
  ],
  "required_fixtures": [],
  "external_dependencies": [],
  "recommended_model": "haiku",
  "rationale": "Simple utility, low criticality, pure function"
}
```

### Example 4: API Route (Medium-High Criticality)

**File:** `app/api/users/route.ts`
**Score:** 75

```json
{
  "file": "app/api/users/route.ts",
  "criticality": "api-route",
  "known_failure_modes": ["Missing auth header returns 500 instead of 401"],
  "test_strategy": "integration",
  "complexity": "medium",
  "test_cases": [
    {
      "name": "should require authentication",
      "priority": "HIGH",
      "pattern": "error_checking",
      "rationale": "Security requirement"
    },
    {
      "name": "should enforce RLS policies",
      "priority": "HIGH",
      "pattern": "worker_fixtures",
      "rationale": "Multi-tenant isolation"
    },
    {
      "name": "should validate input schema",
      "priority": "MEDIUM",
      "pattern": "error_checking",
      "rationale": "API contract enforcement"
    },
    {
      "name": "should return correct HTTP status codes",
      "priority": "MEDIUM",
      "pattern": "error_checking",
      "rationale": "Known failure mode from memory"
    }
  ],
  "required_fixtures": ["workerHousehold"],
  "external_dependencies": ["supabase_client"],
  "recommended_model": "haiku",
  "rationale": "Medium complexity, standard API patterns, planner provides sufficient context"
}
```

---

## Special Cases

### Server Actions

**Detection:** File has `"use server"` or is in `app/actions/`

**Strategy:**

1. Check if business logic is extracted to separate `*-logic.ts` file
2. If yes → Plan tests for logic function (integration)
3. If no → Recommend extraction first, then plan

**Test approach:**

```json
{
  "test_strategy": "integration",
  "test_cases": [
    {
      "name": "Note: Test the *-logic.ts function, not the server action wrapper",
      "priority": "INFO",
      "pattern": "testing_server_actions_rule",
      "rationale": "Server actions are thin wrappers (auth + revalidate). Business logic should be extracted and tested separately."
    }
  ]
}
```

**Reference:** `~/.claude/rules/testing-server-actions.md`

### Files Already in Test-Fixer Memory

**If file appears in memory:**

1. Read memory entry to understand previous failures
2. Ensure new tests cover those failure modes
3. Mark as HIGH priority for those specific test cases

```json
{
  "test_cases": [
    {
      "name": "should handle concurrent updates without race condition",
      "priority": "HIGH",
      "pattern": "worker_fixtures",
      "rationale": "PREVIOUS FAILURE from test-fixer memory: 'TypeError: Cannot read properties of null' due to CASCADE DELETE race condition"
    }
  ]
}
```

---

## Planner Checklist

Before returning plan, verify:

- ✅ Test cases are SPECIFIC to this domain (not generic)
- ✅ Known failure modes from memory are covered
- ✅ Test strategy matches file type (unit vs integration vs E2E)
- ✅ Required fixtures identified
- ✅ Model recommendation justified
- ✅ Complexity assessment accurate
