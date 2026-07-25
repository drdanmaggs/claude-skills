import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '@/types/supabase' // Update with your types path

const supabaseUrl = process.env.SUPABASE_URL!
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY!
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!

/**
 * Service role client — bypasses RLS.
 * Used ONLY for test setup and teardown.
 *
 * CRITICAL: persistSession: false prevents it from interfering
 * with the user client's auth state.
 */
export const serviceClient = createClient<Database>(
  supabaseUrl,
  supabaseServiceRoleKey,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }
)

/**
 * Creates a user-level client that respects RLS.
 * Each test group should create its own client
 * to avoid auth state leaking between tests.
 */
export function createUserClient(): SupabaseClient<Database> {
  return createClient<Database>(
    supabaseUrl,
    supabaseAnonKey,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    }
  )
}

/**
 * Creates an anonymous client (not signed in).
 * Used to test that unauthenticated users
 * cannot access protected data.
 */
export function createAnonClient(): SupabaseClient<Database> {
  return createClient<Database>(
    supabaseUrl,
    supabaseAnonKey,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    }
  )
}
