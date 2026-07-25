-- Migration: Add RLS coverage check function
-- This function is called by the RLS coverage audit test to verify
-- all public tables have RLS enabled.

CREATE OR REPLACE FUNCTION check_rls_coverage()
RETURNS TABLE (table_name text, rls_enabled boolean)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    tablename::text AS table_name,
    rowsecurity AS rls_enabled
  FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY tablename;
$$;
