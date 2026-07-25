# Critical Path Testing Skill

**Risk-driven test generation for critical paths (auth, data integrity, payments)**

## Overview

Unlike traditional coverage-driven testing (test everything to 95%), this skill uses **semantic risk analysis** to identify and deeply test critical code paths. Tests generated are production-ready: parallel-safe, non-flaky, and leverage patterns from test-fixer memory.

## Philosophy

**Quality over quantity. Coverage % is an OUTPUT, not the INPUT.**

- **Risk-driven** (depth-first on critical paths) vs coverage-driven (breadth-first on all files)
- **Semantic analysis** (git history, dependencies, domain knowledge) vs pattern matching (filenames)
- **Baked-in robustness** (MANDATORY patterns from test-fixer) vs basic test generation
- **Memory integration** (30-50% fast path) vs no learning

## When to Use

**Use `/critical-path-testing` when:**
- Starting a new feature with auth/payment/data integrity
- High-risk refactoring (authentication, billing)
- Production bug fix (prevent regression)
- Security audit findings
- Before major release

**Use `/test-coverage-retrofit` when:**
- Legacy codebase needs comprehensive coverage
- Aiming for 95% coverage across all code
- Low-risk utilities and helpers need coverage

**Both are complementary:**
- critical-path-testing → Depth (critical paths tested thoroughly)
- test-coverage-retrofit → Breadth (all code has basic coverage)

## Workflow

```
Phase 0: Discovery & Risk Assessment (60s)
  ├─ Discover session constants
  ├─ Calculate criticality scores (0-100)
  ├─ Check test-fixer memory
  └─ Generate test plan → USER APPROVAL REQUIRED

Phase 1: Test Generation (10 min for 20 files)
  ├─ Sonnet planners (understand criticality)
  ├─ Haiku/Sonnet writers (smart routing)
  ├─ Validation pass (enforce MANDATORY patterns)
  └─ Fix round (max 2 attempts)

Phase 2: Stability Verification (5 min)
  ├─ Run tests 5x in parallel
  ├─ Investigate failures (Opus)
  └─ Pre-commit validation

Phase 3: Pattern Learning (MANDATORY - 30s)
  ├─ Extract patterns from generated tests
  ├─ Record to test-fixer memory
  └─ Proactive search for similar gaps
```

## Criticality Scoring

**Score 0-100 per file based on:**

1. **Domain Category (40 points max)**
   - Authentication/Authorization: 40
   - Payments/Billing: 40
   - Data Integrity: 35
   - RLS Policies: 35
   - API Routes: 30
   - Business Logic: 20
   - Utilities: 5

2. **Risk Indicators (30 points max)**
   - In test-fixer memory: +15
   - Recent bug fixes: +10
   - High complexity: +5
   - External dependencies: +5

3. **Impact Radius (20 points max)**
   - High fan-in (10+ imports): +10
   - Entry point (API, server action): +10
   - Shared utility: +5

4. **Test Gap (10 points max)**
   - No tests: +10
   - Low coverage (<50%): +5
   - Flaky tests: +8

**Thresholds:**
- **80-100: CRITICAL** → Must test in Phase 1
- **60-79: HIGH** → Test if time permits
- **40-59: MEDIUM** → Backlog
- **<40: LOW** → Skip

## MANDATORY Patterns

All generated tests enforce these patterns (validated in Phase 1.4):

1. **Worker-scoped fixtures** (parallel-safe cleanup)
2. **Unique IDs everywhere** (no hardcoded test data)
3. **Error checking ALL DB operations** (catch silent failures)
4. **Proper timeouts** (30s for external services, CI-friendly)
5. **Avoid known flaky patterns** (from test-fixer memory)
6. **CASCADE DELETE safety** (manual child-first deletion)
7. **React hydration waits** (E2E only)

## Expected Outcomes

- **Production-ready tests from day 1** (no flakiness)
- **80-100% coverage of CRITICAL paths** (not 95% of everything)
- **Tests that catch production bugs** (not just line coverage)
- **Learning system** that improves over time (memory accumulation)

## File Structure

```
~/.claude/skills/critical-path-testing/
├── SKILL.md                           # Main orchestrator workflow
├── README.md                          # This file
├── references/
│   ├── criticality-scoring.md         # Scoring algorithm details
│   ├── mandatory-patterns.md          # Pattern enforcement rules
│   ├── planner-prompts.md            # Sonnet planner templates
│   └── common-patterns.md            # Reusable test patterns
├── scripts/
│   └── calculate_criticality.py      # Automated scoring script
└── memory/                           # Linked to test-fixer memory
```

## Testing the Scoring Script

```bash
# Run on current project
cd /path/to/your/project
python ~/.claude/skills/critical-path-testing/scripts/calculate_criticality.py

# Output: .claude/cache/criticality-scores-<timestamp>.json

# Filter by minimum score
python ~/.claude/skills/critical-path-testing/scripts/calculate_criticality.py --min-score 60

# Custom output path
python ~/.claude/skills/critical-path-testing/scripts/calculate_criticality.py --output scores.json
```

**Expected output:**
```
Criticality scores written to: .claude/cache/criticality-scores-20260214-120000.json
Total files analyzed: 127
CRITICAL (80-100): 8
HIGH (60-79): 15
MEDIUM (40-59): 42
LOW (<40): 62
```

**Sanity checks:**
- Auth files should score 80-100
- Utilities should score <40
- Payment processing should score 80-100
- Date formatters should score <20

## Cost Estimate

**For 20 critical files:**
- Phase 0: ~$0.10 (Sonnet planners, scoring)
- Phase 1: ~$0.50 (10 Sonnet planners, 10 Haiku writers, 20 validators)
- Phase 2: ~$0.20 (5 test runs, potential Opus investigations)
- Phase 3: ~$0.05 (pattern extraction, memory recording)
- **Total: ~$0.85**

Compare to test-coverage-retrofit: ~$2.50 for 100 files (breadth vs depth trade-off)

## Comparison to test-coverage-retrofit

| Dimension | test-coverage-retrofit | critical-path-testing |
|-----------|----------------------|---------------------|
| **Goal** | 95% coverage | Critical paths tested |
| **Driver** | Coverage % | Risk score |
| **Selection** | All uncovered files | High criticality only |
| **Validation** | 1-2 runs | 5 runs parallel |
| **Memory** | None | Deep integration |
| **Pattern Search** | None | Proactive (test-fixer style) |
| **When to Use** | Retrofit legacy code | New features, high-risk areas |

## Related Skills

- `/test-fixer` - Diagnose and fix test failures (provides memory patterns)
- `/test-coverage-retrofit` - Comprehensive coverage for legacy code
- `/tdd` - Test-driven development workflow

## References

See files in `references/` directory for detailed documentation:
- Criticality scoring algorithm
- Mandatory pattern enforcement
- Planner prompt templates
- Common test patterns
