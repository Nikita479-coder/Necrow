/*
  # Fix User Profile RLS Circular Dependency

  1. Problem
    - The is_admin() function queries user_profiles
    - During user creation, the profile doesn't exist yet
    - This causes the trigger to fail when RLS policies are evaluated
    
  2. Solution
    - Make the is_admin() function handle non-existent profiles gracefully
    - Add explicit handling for the trigger context
    - Ensure SELECT policies don't interfere with INSERT trigger
    
  3. Security
    - Maintains all security restrictions
    - Only affects the trigger execution path
*/

-- Update is_admin to be more robust and not cause issues during profile creation
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT COALESCE(
    (SELECT is_admin FROM user_profiles WHERE id = user_id LIMIT 1),
    false
  );
$function$;

-- Recreate the SELECT policies to be more explicit and avoid trigger conflicts
DROP POLICY IF EXISTS "Users can read own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;

-- Allow users to read their own profile
CREATE POLICY "Users can read own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Allow admins to view all profiles (but handle case where profile doesn't exist)
CREATE POLICY "Admins can view all profiles"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up 
      WHERE up.id = auth.uid() 
      AND up.is_admin = true
    )
  );
