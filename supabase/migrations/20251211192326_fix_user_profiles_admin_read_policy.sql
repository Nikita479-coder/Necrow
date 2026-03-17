/*
  # Fix Admin Read Policy for User Profiles

  ## Issue
  The current "Admins can view all profiles via JWT" policy checks JWT app_metadata,
  but admins are identified by the `is_admin` column in user_profiles table.

  ## Solution
  Add a new policy that allows admins (based on user_profiles.is_admin) to view all profiles.
  Also allow staff members to search for users.
*/

DROP POLICY IF EXISTS "Admins can view all profiles via JWT" ON user_profiles;

CREATE POLICY "Admins and staff can view all profiles"
ON user_profiles
FOR SELECT
TO authenticated
USING (
  auth.uid() = id
  OR EXISTS (
    SELECT 1 FROM user_profiles up 
    WHERE up.id = auth.uid() AND up.is_admin = true
  )
  OR EXISTS (
    SELECT 1 FROM admin_staff s 
    WHERE s.id = auth.uid() AND s.is_active = true
  )
);
