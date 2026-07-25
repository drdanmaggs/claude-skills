/**
 * Multi-User RLS Test Clients (Dynamic User Creation Pattern)
 *
 * Use this pattern when your project has household isolation helpers
 * (like createIsolatedTestHousehold) that create dynamic test users.
 *
 * This is BETTER than manual test user setup because:
 * - Tests are self-sufficient (don't depend on pre-existing DB state)
 * - Parallel test execution is safe (each suite gets unique users)
 * - No test pollution (clean slate every time)
 *
 * Adapt this template by:
 * 1. Update Database type import path
 * 2. Replace createIsolatedTestHousehold with your project's helper
 * 3. Update TEST_CONFIG import path
 */

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/types/database.types"; // Update this import
import { TEST_CONFIG } from "@/tests/config"; // Update this import
import {
  createIsolatedTestHousehold, // Replace with your project's helper
  cleanupIsolatedTestHousehold,
  type IsolatedTestHousehold,
} from "@/tests/helpers/isolated-test-household"; // Update this import
import { createServiceRoleClient } from "@/lib/supabase/server"; // Update this import

export interface MultiUserRLSContext {
  // User A (Household A)
  userA: {
    client: SupabaseClient<Database>;
    household: IsolatedTestHousehold;
    email: string;
    password: string;
  };
  // User B (Household B)
  userB: {
    client: SupabaseClient<Database>;
    household: IsolatedTestHousehold;
    email: string;
    password: string;
  };
  // Service role client (for setup/verification)
  serviceClient: SupabaseClient<Database>;
}

/**
 * Create two isolated users with separate households for RLS testing
 *
 * @returns MultiUserRLSContext with both users and service client
 *
 * @example
 * ```typescript
 * describe('RLS - Household Isolation', () => {
 *   let context: MultiUserRLSContext;
 *
 *   beforeAll(async () => {
 *     context = await createMultiUserRLSContext();
 *   });
 *
 *   afterAll(async () => {
 *     await cleanupMultiUserRLSContext(context);
 *   });
 *
 *   it('should prevent User A from reading User B meal plans', async () => {
 *     // Create data for User B
 *     const { data: userBData } = await context.serviceClient
 *       .from('meal_plans')
 *       .insert({ household_id: context.userB.household.householdId, ... })
 *       .select('id')
 *       .single();
 *
 *     // Try to read as User A (should be blocked by RLS)
 *     const { data, error } = await context.userA.client
 *       .from('meal_plans')
 *       .select('*')
 *       .eq('id', userBData.id);
 *
 *     expect(error).toBeNull();
 *     expect(data).toEqual([]); // RLS blocks access
 *   });
 * });
 * ```
 */
export async function createMultiUserRLSContext(): Promise<MultiUserRLSContext> {
  // Create service role client for setup
  const serviceClient = createServiceRoleClient();

  // Create User A household with dynamic auth user
  const householdA = await createIsolatedTestHousehold(serviceClient);

  // Create User B household with dynamic auth user
  const householdB = await createIsolatedTestHousehold(serviceClient);

  // Get auth user emails (created by household helper)
  const { data: userAAuth } = await serviceClient.auth.admin.getUserById(
    householdA.authUserId,
  );
  const { data: userBAuth } = await serviceClient.auth.admin.getUserById(
    householdB.authUserId,
  );

  if (!userAAuth.user?.email || !userBAuth.user?.email) {
    throw new Error("Failed to retrieve auth user emails");
  }

  // Create authenticated clients for both users
  // Note: Password is hardcoded in createIsolatedTestHousehold as "testpassword123"
  // Adjust this if your helper uses different password
  const clientA = createClient<Database>(
    TEST_CONFIG.SUPABASE.URL,
    TEST_CONFIG.SUPABASE.ANON_KEY,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );

  const { error: signInErrorA } = await clientA.auth.signInWithPassword({
    email: userAAuth.user.email,
    password: "testpassword123", // From createIsolatedTestHousehold
  });

  if (signInErrorA) {
    throw new Error(`Failed to sign in User A: ${signInErrorA.message}`);
  }

  const clientB = createClient<Database>(
    TEST_CONFIG.SUPABASE.URL,
    TEST_CONFIG.SUPABASE.ANON_KEY,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );

  const { error: signInErrorB } = await clientB.auth.signInWithPassword({
    email: userBAuth.user.email,
    password: "testpassword123", // From createIsolatedTestHousehold
  });

  if (signInErrorB) {
    throw new Error(`Failed to sign in User B: ${signInErrorB.message}`);
  }

  return {
    userA: {
      client: clientA,
      household: householdA,
      email: userAAuth.user.email,
      password: "testpassword123",
    },
    userB: {
      client: clientB,
      household: householdB,
      email: userBAuth.user.email,
      password: "testpassword123",
    },
    serviceClient,
  };
}

/**
 * Clean up multi-user RLS test context
 *
 * Deletes both households (CASCADE removes all child data)
 * and both auth users created during setup.
 *
 * @param context - Context returned from createMultiUserRLSContext
 */
export async function cleanupMultiUserRLSContext(
  context: MultiUserRLSContext,
): Promise<void> {
  // Clean up User A household and auth user
  await cleanupIsolatedTestHousehold(
    context.serviceClient,
    context.userA.household,
  );

  // Clean up User B household and auth user
  await cleanupIsolatedTestHousehold(
    context.serviceClient,
    context.userB.household,
  );
}
