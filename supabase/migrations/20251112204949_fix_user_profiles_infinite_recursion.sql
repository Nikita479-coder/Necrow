/*
  # Fix infinite recursion in user_profiles RLS policies

  1. Changes
    - Drop the problematic "Admins can view all profiles" policy that causes infinite recursion
    - Create a new admin policy that doesn't reference user_profiles table
    - Use a function that safely checks admin status using a direct query bypassing RLS
    
  2. Security
    - Maintains proper access control
    - Admins can view all profiles
    - Regular users can only view their own profile
*/

-- Drop the problematic policy
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;

-- Create a function to check if a user is admin (bypasses RLS)
CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM user_profiles WHERE id = user_id LIMIT 1),
    false
  );
$$;

-- Create new admin policy using the function
CREATE POLICY "Admins can view all profiles"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (is_admin(auth.uid()));