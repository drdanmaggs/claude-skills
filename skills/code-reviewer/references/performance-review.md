# Performance Review Reference

Stack: Next.js 16 App Router, React 19, Supabase. Flag real problems, not hypothetical ones.

## N+1 Queries — Flag Confidently (90+)

DB queries inside loops are almost always bugs, not style:

```ts
// BAD: N+1 — one query per item
for (const item of items) {
  const data = await supabase.from('details').select().eq('item_id', item.id)
}

// GOOD: single batched query
const { data } = await supabase.from('details').select().in('item_id', itemIds)
```

Flag: `.from()` inside `.map()`, `.forEach()`, `for` loops, or recursive functions.

## Data Fetching Waterfalls — Flag at 80+

Sequential awaits that are clearly independent:

```ts
// BAD: sequential when both can run in parallel
const user = await getUser(id)
const settings = await getSettings(id)  // doesn't depend on user

// GOOD
const [user, settings] = await Promise.all([getUser(id), getSettings(id)])
```

Only flag when you can confirm the operations are truly independent (second doesn't use result of first).

## Unbounded Fetches — Flag at 80+

Queries with no LIMIT on tables that grow with user data:

```ts
// BAD: could return thousands of rows
const { data } = await supabase.from('messages').select('*')

// GOOD
const { data } = await supabase.from('messages').select('*').limit(50)
```

Don't flag: lookup tables, config tables, or tables bounded by design (e.g., `categories`).

## React Render Cost Model

### When useMemo/useCallback IS worth flagging (80+)

- Callback passed to a `React.memo` child — without `useCallback`, child re-renders every time
- Value in a dependency array of another `useEffect`/`useMemo` — unstable ref causes infinite loop
- Genuinely expensive computation (>1ms, e.g., sorting thousands of items, complex transforms)

### When useMemo/useCallback is NOT worth flagging (automatic dismiss)

- Simple transforms: `items.filter(...)`, `items.map(...)` on small arrays — React re-renders are cheap
- Stable values: objects/arrays created from stable primitives — React 19 compiler handles this
- Callbacks not passed to memoised children — adding useCallback adds overhead with no benefit
- Any case where you're suggesting "for good practice" without a concrete render problem

**Hard rule:** Never flag missing `useMemo`/`useCallback` unless you can identify the specific render problem it prevents.

## Next.js RSC — Flag at 70+ (needs validation)

Flag `use client` only when a server component would clearly work:
- Component has no hooks, no event handlers, no browser APIs
- Moving to server component would eliminate client bundle weight with no functional change

Don't flag: `use client` on components that pass callbacks or use any browser feature.

## SELECT * — Flag Sparingly

Only flag on:
- Hot paths (called on every page load or in loops)
- Tables with many columns including large text/jsonb fields

Don't flag as a general rule — premature column selection is YAGNI.

## Explicit YAGNI Filter

These are NOT performance findings:
- "Could be slow at scale" — current code must have the problem
- "Consider caching" — unless there's a demonstrable redundant fetch in the diff
- "This could cause re-renders" — without identifying what actually re-renders unnecessarily
- Any suggestion with "might", "could", "potentially" — these are speculative

## When to Use Context7

Use `mcp__context7__resolve-library-id` then `mcp__context7__query-docs` to verify:
- Whether a flagged React pattern is actually a performance concern in React 19
- Whether a Next.js App Router caching pattern behaves as you expect
- Whether Supabase client handles connection pooling in a way that affects your finding

Don't use context7 to fish for potential issues.
