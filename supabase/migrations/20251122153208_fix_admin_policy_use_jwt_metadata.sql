/*
  # Fix Admin Policy - Use JWT Metadata Instead of Recursive Query

  1. Changes
    - Drop the recursive "Admins can view all profiles" policy
    - Create a new admin policy that checks app_metadata in JWT instead
    - This avoids infinite recursion by not querying user_profiles within the policy

  2. Security
    - Admin flag is stored in app_metadata which users cannot modify
    - Only service role can update app_metadata
    - Policy now checks JWT claims directly without database queries
*/

-- Drop the problematic recursive policy
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;

-- Create new admin policy using JWT metadata
CREATE POLICY "Admins can view all profiles via JWT"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean = true
  );
