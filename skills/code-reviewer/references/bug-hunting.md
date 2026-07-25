# Bug Hunting Reference

Stack-specific patterns for: Next.js 16 App Router, Supabase, React 19, TypeScript strict.

## Auth & Security Patterns

**Flag confidently (90+):**

- **Server action missing auth guard** — mutations without `requireAdmin()` or session check before DB write
  ```ts
  // BAD: no auth check
  export async function deleteItem(id: string) {
    await supabase.from('items').delete().eq('id', id)
  }
  ```
- **Private key with NEXT_PUBLIC_ prefix** — secrets prefixed `NEXT_PUBLIC_` are bundled into the client
- **`process.env.SECRET` in a client component** — env vars without NEXT_PUBLIC_ are undefined client-side but the reference exposes the key name
- **Supabase `service_role` key in client-facing code** — bypasses RLS entirely; must only appear in server-side code
- **RLS bypass** — Supabase queries on user-scoped tables missing `.eq('user_id', userId)` or equivalent filter when RLS is not enforced
- **CSRF** — state-changing server actions/API routes without protection (Next.js server actions have CSRF protection built-in; custom API routes do not)

**Flag at 80+:**
- SQL injection risk — user input concatenated into raw queries (Supabase parameterises `.from()` calls; risk is in `.rpc()` with string interpolation)
- XSS via `dangerouslySetInnerHTML` with unsanitised user content

## Logic Error Patterns

**Flag confidently (90+):**

- **Missing `await` on async call** — the operation becomes a no-op silently
  ```ts
  // BAD: promise never awaited, mutation doesn't run
  supabase.from('items').insert(data)
  ```
- **Discriminated union missing branch** — TypeScript exhaustiveness check absent, runtime crash on unhandled variant
  ```ts
  // BAD: if 'pending' state added later, this silently falls through
  if (status === 'success') ... else if (status === 'error') ...
  ```

**Flag at 80+:**
- **Stale closure in useEffect** — dependency array missing a variable that changes, causing the effect to read stale values
- **Optional chaining hiding null bugs** — `foo?.bar?.baz` on a path that should never be null (masks real bugs); NOT for genuinely nullable values

## What NOT to Flag

- Optional chaining where null is a valid runtime state
- Generic "could be insecure" without proof of exploitability in the actual code
- Any pattern that pre-existed this change
- TypeScript type assertions (`as Foo`) that are already covered by the type system
- Error handling patterns that follow the project's established convention (check the rest of the file first)
