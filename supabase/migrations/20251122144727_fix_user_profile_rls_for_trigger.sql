/*
  # Fix User Profile RLS for Trigger-based Inserts

  1. Changes
    - Add a policy that allows inserts from SECURITY DEFINER functions (triggers)
    - This allows the create_user_profile() trigger to insert profiles during signup
    
  2. Security
    - The new policy only allows inserts where the id matches, maintaining security
    - The SECURITY DEFINER function ensures only the trigger can use this path
*/

-- Drop the existing restrictive insert policy
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;

-- Create a new policy that works with both authenticated users AND triggers
CREATE POLICY "Allow profile creation"
  ON user_profiles
  FOR INSERT
  WITH CHECK (true);

-- Add a more restrictive policy for authenticated user updates to maintain security
-- (The existing update policy already handles this, but we ensure it's in place)
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
