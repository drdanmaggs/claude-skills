import { serviceClient, createUserClient } from './supabase-test-clients'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '@/types/supabase' // Update with your types path

/**
 * Signs in a test user and returns an authenticated client.
 * Throws if sign-in fails — this is a test infrastructure
 * failure, not a test failure.
 */
export async function signInAs(
  email: string,
  password: string
): Promise<SupabaseClient<Database>> {
  const client = createUserClient()

  const { error, data } = await client.auth.signInWithPassword({
    email,
    password,
  })

  if (error) {
    throw new Error(
      `Test setup failed: could not sign in as ${email}: ${error.message}`
    )
  }

  if (!data.session) {
    throw new Error(
      `Test setup failed: no session returned for ${email}`
    )
  }

  return client
}

/**
 * Checks whether an error is an RLS violation.
 * Useful for asserting that INSERT operations
 * are correctly blocked.
 */
export function isRlsError(error: { message: string } | null): boolean {
  if (!error) return false
  return error.message.startsWith(
    'new row violates row-level security policy'
  )
}

/**
 * Creates test data using the service role client
 * (bypasses RLS). Returns the created record IDs
 * for later cleanup.
 */
export async function createTestData<T extends Record<string, unknown>>(
  table: string,
  data: T | T[]
): Promise<string[]> {
  const records = Array.isArray(data) ? data : [data]

  const { data: created, error } = await serviceClient
    .from(table)
    .insert(records)
    .select('id')

  if (error) {
    throw new Error(
      `Test setup failed: could not create test data in ${table}: ${error.message}`
    )
  }

  return (created ?? []).map((r: { id: string }) => r.id)
}

/**
 * Cleans up test data using the service role client.
 * Call in afterAll/afterEach to prevent test pollution.
 */
export async function cleanupTestData(
  table: string,
  ids: string[]
): Promise<void> {
  if (ids.length === 0) return

  const { error } = await serviceClient
    .from(table)
    .delete()
    .in('id', ids)

  if (error) {
    console.warn(
      `Test cleanup warning: could not clean ${table}: ${error.message}`
    )
  }
}
