# Architecture and Setup

## Two-Client Architecture

```
┌─────────────────────────────────────┐
│         Vitest Test Runner          │
├─────────────────────────────────────┤
│                                     │
│  ┌───────────┐   ┌───────────────┐  │
│  │  Service   │   │  User Client  │  │
│  │  Role      │   │  (anon key)   │  │
│  │  Client    │   │               │  │
│  │            │   │  Signs in as  │  │
│  │  Creates/  │   │  test users   │  │
│  │  cleans    │   │  to test RLS  │  │
│  │  test data │   │               │  │
│  └─────┬──────┘   └───────┬───────┘  │
│        │                  │          │
└────────┼──────────────────┼──────────┘
         │                  │
         ▼                  ▼
┌─────────────────────────────────────┐
│     Remote Supabase Branch          │
│     (real Postgres + real RLS)      │
└─────────────────────────────────────┘
```

**Service Role Client**: Bypasses RLS. Used ONLY for setup and cleanup. Never in assertions.

**User Client**: Uses public anon key. Signs in as test users. This is what your app does — tests real behavior.

## Environment Variables

Create `.env.test` (add to `.gitignore`):

```env
# Remote Supabase branch credentials
SUPABASE_URL=https://your-branch-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Test user credentials (create manually in branch)
TEST_USER_A_EMAIL=testusera@test.com
TEST_USER_A_PASSWORD=test-password-a-secure-123
TEST_USER_B_EMAIL=testuserb@test.com
TEST_USER_B_PASSWORD=test-password-b-secure-123
```

## Vitest Configuration

Add separate project for integration tests:

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['src/**/*.integration.test.ts'],

    // CRITICAL: run sequentially (RLS tests depend on auth state)
    sequence: {
      shuffle: false,
      concurrent: false,
    },
    fileParallelism: false,

    testTimeout: 15000, // Longer for network requests
  },
})
```

Or separate config file:

```typescript
// vitest.integration.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['src/**/*.integration.test.ts'],
    sequence: { shuffle: false, concurrent: false },
    fileParallelism: false,
    testTimeout: 15000,
    setupFiles: ['./src/tests/integration-setup.ts'],
  },
})
```

With npm script:

```json
{
  "scripts": {
    "test:integration": "vitest run --config vitest.integration.config.ts"
  }
}
```

## Client Setup

See `assets/supabase-test-clients.ts` for template.

Key points:

```typescript
// Service role — bypasses RLS
export const serviceClient = createClient<Database>(
  supabaseUrl,
  supabaseServiceRoleKey,
  {
    auth: {
      persistSession: false, // CRITICAL — prevents session leaking
      autoRefreshToken: false,
    },
  }
)

// User client — respects RLS
export function createUserClient(): SupabaseClient<Database> {
  return createClient<Database>(
    supabaseUrl,
    supabaseAnonKey,
    {
      auth: {
        persistSession: false, // CRITICAL
        autoRefreshToken: false,
      },
    }
  )
}

// Anonymous client
export function createAnonClient(): SupabaseClient<Database> {
  return createClient<Database>(
    supabaseUrl,
    supabaseAnonKey,
    {
      auth: {
        persistSession: false, // CRITICAL
        autoRefreshToken: false,
      },
    }
  )
}
```

## Test Helpers

See `assets/rls-test-helpers.ts` for template.

Key functions:

- `signInAs(email, password)` - Returns authenticated client
- `isRlsError(error)` - Checks if error is RLS violation
- `createTestData(table, data)` - Creates records using service role
- `cleanupTestData(table, ids)` - Cleans up in afterAll

## File Structure

```
src/
  tests/
    utils/
      supabase-test-clients.ts
      rls-test-helpers.ts
      check-connection.ts
    rls/
      meal-plans.integration.test.ts
      anonymous-access.integration.test.ts
      nested-data.integration.test.ts
      rls-coverage.integration.test.ts
```

## CI Integration

```yaml
- name: Run RLS integration tests
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_BRANCH_URL }}
    SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
    TEST_USER_A_EMAIL: ${{ secrets.TEST_USER_A_EMAIL }}
    TEST_USER_A_PASSWORD: ${{ secrets.TEST_USER_A_PASSWORD }}
    TEST_USER_B_EMAIL: ${{ secrets.TEST_USER_B_EMAIL }}
    TEST_USER_B_PASSWORD: ${{ secrets.TEST_USER_B_PASSWORD }}
  run: npm run test:integration
```
