/*
  # Fix Copy Relationships Admin Policy

  ## Problem
  The admin policy for copy_relationships uses a subquery on user_profiles
  which can cause recursive RLS issues when user_profiles has RLS enabled.

  ## Solution
  Update the policy to use the is_user_admin() helper function which
  is SECURITY DEFINER and bypasses RLS.

  ## Changes
  1. Drop the existing admin policy
  2. Create new policy using is_user_admin() function
*/

-- Drop the problematic admin policy
DROP POLICY IF EXISTS "Admins can view all copy relationships" ON copy_relationships;

-- Create new admin policy using the helper function
CREATE POLICY "Admins can view all copy relationships"
  ON copy_relationships
  FOR SELECT
  TO authenticated
  USING (is_user_admin((SELECT auth.uid())));

-- Also add admin update policy if missing
DROP POLICY IF EXISTS "Admins can update all copy relationships" ON copy_relationships;

CREATE POLICY "Admins can update all copy relationships"
  ON copy_relationships
  FOR UPDATE
  TO authenticated
  USING (is_user_admin((SELECT auth.uid())))
  WITH CHECK (is_user_admin((SELECT auth.uid())));
