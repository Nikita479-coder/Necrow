/*
  # Fix user_profiles infinite recursion in RLS policy

  1. Problem
    - The "Admins and staff can view all profiles" policy references user_profiles 
      within its own condition, causing infinite recursion
  
  2. Solution
    - Drop the problematic policy
    - Create a helper function that bypasses RLS to check admin status
    - Recreate the policy using the helper function
*/

-- Drop the problematic policy
DROP POLICY IF EXISTS "Admins and staff can view all profiles" ON user_profiles;

-- Create a helper function with SECURITY DEFINER to check if user is admin
-- This function runs with elevated privileges and bypasses RLS
CREATE OR REPLACE FUNCTION is_current_user_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()),
    false
  );
$$;

-- Create a helper function to check if user is active staff
CREATE OR REPLACE FUNCTION is_current_user_staff()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT COALESCE(
    (SELECT is_active FROM admin_staff WHERE id = auth.uid()),
    false
  );
$$;

-- Recreate the policy using the helper functions (no self-reference)
CREATE POLICY "Admins and staff can view all profiles"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = id 
    OR is_current_user_admin() 
    OR is_current_user_staff()
  );
