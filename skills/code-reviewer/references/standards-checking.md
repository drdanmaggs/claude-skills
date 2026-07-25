# Standards Checking Reference

## CLAUDE.md Hierarchy

- Root `CLAUDE.md` applies globally to all files in the repo
- A `CLAUDE.md` in a subdirectory applies to that directory and all its children
- More specific rules override more general ones; both apply when there's no conflict
- Pass ALL discovered CLAUDE.md files to this agent — the orchestrator finds them

## What "Clear Violation" Means

You MUST be able to:
1. Quote the exact rule text from a CLAUDE.md file
2. Point to the specific line in the diff that breaks it
3. Show that the breach is unambiguous (not interpretive)

If you can't do all three, do not flag it.

## What to Reject

- Interpretive readings — "I think this might violate the spirit of..."
- Style preferences not explicitly stated in CLAUDE.md
- Rules from external style guides unless CLAUDE.md references them
- Patterns that are debatable (if two senior engineers would disagree, dismiss)
- CLAUDE.md rules that only appear in a parent directory when the child dir has overriding guidance

## Most Commonly Violated Rules (Quick Reference)

These rules appear in the global `~/.claude/CLAUDE.md` and project CLAUDE.md files. Check for:

**Type safety (rules/code-quality.md):**
- `any` types — banned without exception. `as any`, `@ts-ignore` to silence type warnings → always flag
- `unknown` required for untyped external data, with runtime validation at the boundary

**Test anti-patterns (rules/testing.md):**
- `vi.clearAllMocks()` with module-level mocks → causes mock contamination
- Hardcoded test user IDs → should use worker-scoped fixtures
- `waitFor(() => expect(await findBy...))` → double-polling
- `page.waitForTimeout(N)` → arbitrary delays
- `expect(await locator.isVisible()).toBe(true)` → use `await expect(locator).toBeVisible()`
- Hardcoded `localhost:3000` in Playwright tests
- CSS selectors in Playwright → use `getByRole()`, `getByLabel()`, `getByTestId()`
- `fireEvent` instead of `userEvent`

**UI patterns (CLAUDE.md):**
- `window.confirm()` or `window.alert()` for confirmations → must use `@/components/ui/alert`

**Architecture patterns (rules/testing.md):**
- Async server actions tested directly in Vitest → extract logic functions instead

## Non-Example Violations (Looks Like But Isn't)

- A `vi.mock()` at the top of a test file → this is fine; only flag if it's inside a test block
- Using `unknown` without validation → only flag if it's actually passed to typed code without narrowing
- Missing `await` on `router.push()` → Next.js App Router's `router.push` is synchronous, no await needed
- A `console.log` left in → linter territory, not a CLAUDE.md violation unless explicitly banned
