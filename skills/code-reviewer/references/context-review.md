# Context Review Reference

Read full modified files (not just the diff) to catch semantic issues invisible in isolation.

## Next.js App Router Boundaries

**When `use client` is required** (missing it causes a runtime error):
- Component uses React hooks (`useState`, `useEffect`, `useRef`, etc.)
- Component attaches event handlers (`onClick`, `onChange`, etc.)
- Component uses browser APIs (`window`, `document`, `localStorage`)

**When `use client` is NOT needed** (flag if present unnecessarily):
- Component only renders JSX from props/server data with no interactivity
- Using `use client` forces the whole subtree into the client bundle

**Server component patterns:**
- Data fetching should happen in server components — `async` components with `await` at the top
- `revalidatePath()` / `revalidateTag()` must be called after mutations in server actions
- `createClient()` from `@/lib/supabase/server` must be called per-request, not at module level

**Common context issues to catch:**
- Broken imports to renamed or deleted symbols — trace the actual export in the changed files
- Type mismatches where a prop type changed but call sites weren't updated
- New code contradicting the established pattern in the same file (check surrounding context)

## Supabase Client Scoping

**Flag:**
- `const supabase = createClient()` at module level in server-side code — creates a single shared client across requests, bypassing per-request auth context
- Correct pattern: `const supabase = await createClient()` inside the function/action body

**Don't flag:**
- Module-level Supabase client in client components (browser context is per-session)
- Service role client created at module level in scripts/seed files (no request context)

## TypeScript Context Issues

**Flag:**
- A type change that makes callers type-unsafe — check actual callers in the file, not just the changed signature
- Narrowing that's incorrect given the surrounding control flow (e.g., asserting non-null after a conditional that already handled null)

**Don't flag:**
- Type widening that's intentional (check if there's a comment or PR description explaining it)
- Intersection/union changes that TypeScript's structural typing handles correctly

## Error Handling Context

**Flag:**
- New async code path with no error handling where the calling context has no error boundary
- `supabase` query result used without checking `.error` when the operation is critical (data loss risk)

**Don't flag:**
- Missing try/catch in Next.js server actions — Next.js wraps these in its own error boundary
- Supabase `.select()` without error check — reads failing silently is often acceptable (returns empty)
- Omitted error handling that matches the rest of the file's pattern

## When to Use Context7

Use `mcp__context7__resolve-library-id` then `mcp__context7__query-docs` when:
- Unsure if a Next.js App Router pattern is valid (cache behaviour, streaming, Suspense)
- Unsure if a Supabase RLS or auth pattern is correct
- Unsure about React 19 concurrent features (transitions, deferred values)

Do NOT use context7 for things you already know confidently, or to fish for potential issues.
