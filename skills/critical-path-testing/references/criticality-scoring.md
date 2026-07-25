# Criticality Scoring Algorithm

**Purpose:** Semantic risk assessment (not pattern matching)

**Output:** Score 0-100 per file

---

## Scoring Components

### 1. Domain Category (40 points max)

| Category                         | Points | Examples                                                   |
| -------------------------------- | ------ | ---------------------------------------------------------- |
| **Authentication/Authorization** | 40     | login, signup, session, JWT, OAuth, RLS policies           |
| **Payments/Billing**             | 40     | Stripe, checkout, subscriptions, invoices                  |
| **Data Integrity**               | 35     | User data CRUD, household data, critical business entities |
| **RLS Policies**                 | 35     | Row-level security, permission checks                      |
| **Public API Routes**            | 30     | `/api/*` endpoints, webhooks                               |
| **Business Logic**               | 20     | Core domain functions, calculations                        |
| **Utilities**                    | 5      | Date formatting, string helpers                            |

**Detection:**

- File path patterns: `auth/`, `payment/`, `/api/`
- Function names: `login`, `authenticate`, `processPayment`, `authorize`
- Imports: `@stripe`, `jsonwebtoken`, `supabase.rpc`, RLS helper functions
- Comments/docs: "critical", "security", "payment"

### 2. Risk Indicators (30 points max)

| Indicator                 | Points | Detection                                                                           |
| ------------------------- | ------ | ----------------------------------------------------------------------------------- |
| **In test-fixer memory**  | 15     | File appears in `test-fixer/memory/*/common-failures.md` or `test-fixes.md`         |
| **Recent bug fixes**      | 10     | Git log last 90 days: `git log --since="90 days ago" --grep="fix\|bug" --name-only` |
| **High complexity**       | 5      | Cyclomatic complexity >10, LOC >300, nested conditionals                            |
| **External dependencies** | 5      | Imports Supabase, Stripe, OpenAI, third-party APIs                                  |

**Complexity heuristics:**

```python
complexity_score = (
    (lines_of_code > 300) * 2 +
    (cyclomatic_complexity > 10) * 2 +
    (max_nesting_depth > 4) * 1
)
```

### 3. Impact Radius (20 points max)

| Indicator          | Points | Detection                                                                  |
| ------------------ | ------ | -------------------------------------------------------------------------- |
| **High fan-in**    | 10     | Called by 10+ files: `grep -r "import.*from.*{filename}" --include="*.ts"` |
| **Entry point**    | 10     | API route, server action, webhook handler                                  |
| **Shared utility** | 5      | In `lib/`, `utils/`, imported by 5+ files                                  |

**Entry point detection:**

- File path: `app/api/`, `app/actions/`
- Exports: `export async function POST`, `export async function GET`
- Decorators: `"use server"`

### 4. Test Gap (10 points max)

| Gap Level          | Points | Detection                                                        |
| ------------------ | ------ | ---------------------------------------------------------------- |
| **No tests exist** | 10     | No matching `.test.ts` or `.spec.ts` file                        |
| **Low coverage**   | 5      | Coverage <50% (from `coverage/coverage-final.json`)              |
| **Flaky tests**    | 8      | File appears in test-fixer memory with "flaky" or "intermittent" |

**Coverage check:**

```python
# Parse coverage-final.json
if file not in coverage_data:
    test_gap_score = 10
elif coverage_data[file]['lines']['pct'] < 50:
    test_gap_score = 5
else:
    test_gap_score = 0
```

---

## Thresholds

| Score      | Priority | Action                        |
| ---------- | -------- | ----------------------------- |
| **80-100** | CRITICAL | MUST test in Phase 1          |
| **60-79**  | HIGH     | Test if time permits          |
| **40-59**  | MEDIUM   | Backlog (create GitHub issue) |
| **<40**    | LOW      | Skip                          |

---

## Example Calculations

### Example 1: lib/auth/login-logic.ts

```
Domain Category:     40 (Authentication core)
Risk Indicators:     25
  - In test-fixer memory: 15
  - Recent bug fix: 10
  - External deps (Supabase Auth): 5 (capped at 30)
Impact Radius:       20
  - Entry point (server action): 10
  - High fan-in (12 files import): 10
Test Gap:            10 (No tests exist)

TOTAL: 95 → CRITICAL
```

### Example 2: lib/utils/format-date.ts

```
Domain Category:     5 (Utility)
Risk Indicators:     0
  - Not in memory: 0
  - No recent bugs: 0
  - Low complexity: 0
  - No external deps: 0
Impact Radius:       5
  - Shared utility (8 files import): 5
Test Gap:            10 (No tests exist)

TOTAL: 20 → LOW (skip)
```

### Example 3: lib/payments/process-payment-logic.ts

```
Domain Category:     40 (Payment processing)
Risk Indicators:     20
  - In test-fixer memory: 15
  - External deps (Stripe): 5
Impact Radius:       20
  - Entry point (server action): 10
  - High fan-in (15 files import): 10
Test Gap:            5 (Coverage 45%)

TOTAL: 85 → CRITICAL
```

---

## Data Sources

### Git History

```bash
# Recent bug fixes (last 90 days)
git log --since="90 days ago" --grep="fix\|bug" --name-only --pretty=format: | sort | uniq -c | sort -rn

# Recent commits per file (churn indicator)
git log --since="90 days ago" --name-only --pretty=format: | grep "\.ts$" | sort | uniq -c | sort -rn
```

### Dependency Analysis

```bash
# Find files with high fan-in
for file in $(find lib app -name "*.ts" -not -name "*.test.ts"); do
  count=$(grep -r "import.*from.*$(basename $file .ts)" --include="*.ts" | wc -l)
  echo "$count $file"
done | sort -rn

# Find entry points
grep -r "use server" app/ --include="*.ts" -l
find app/api -name "route.ts"
```

### Test-Fixer Memory

```bash
# Calculate project hash
WORKSPACE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_HASH=$(echo -n "$WORKSPACE_ROOT" | shasum -a 256 | cut -d' ' -f1 | head -c 32)

# Check memory files
cat ~/.claude/skills/test-fixer/memory/$PROJECT_HASH/common-failures.md
cat ~/.claude/skills/test-fixer/memory/$PROJECT_HASH/test-fixes.md
cat ~/.claude/skills/test-fixer/memory/$PROJECT_HASH/critical-path-coverage.md
```

### Coverage Data

```bash
# Generate coverage if not exists
pnpm test -- --coverage

# Parse coverage
cat coverage/coverage-final.json | jq -r 'to_entries[] | "\(.key) \(.value.lines.pct)"'
```

---

## Scoring Script Output Format

**JSON file:** `.claude/cache/criticality-scores-[timestamp].json`

```json
{
  "lib/auth/login-logic.ts": {
    "score": 95,
    "breakdown": {
      "domain_category": 40,
      "risk_indicators": 25,
      "impact_radius": 20,
      "test_gap": 10
    },
    "details": {
      "category": "authentication",
      "in_memory": true,
      "recent_bugs": 1,
      "complexity": "medium",
      "external_deps": ["supabase_auth"],
      "fan_in": 12,
      "entry_point": true,
      "test_coverage": 0
    },
    "reason": "Authentication core (40) + in test-fixer memory (15) + recent bug (10) + entry point (20) + no tests (10)",
    "test_type": "integration",
    "priority": "CRITICAL"
  }
}
```

---

## Validation

**Sanity checks:**

- Auth files should score 80-100
- Utilities should score <40
- Payment processing should score 80-100
- Date formatters should score <20

**If scoring looks wrong:**

1. Check data sources (git log, coverage, memory)
2. Verify domain category detection
3. Review threshold calibration
