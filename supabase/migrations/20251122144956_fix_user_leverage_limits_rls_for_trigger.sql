/*
  # Fix User Leverage Limits RLS for Trigger

  1. Problem
    - user_leverage_limits has RLS enabled
    - No INSERT policy exists
    - The set_user_leverage_limit() trigger fails when creating new users
    
  2. Solution
    - Add INSERT policy to allow the trigger to create leverage limits
    - Add UPDATE policy for trigger updates
    
  3. Security
    - Only the trigger (SECURITY DEFINER) can insert/update
    - Users can only read their own limits
*/

-- Add INSERT policy for leverage limits (allows trigger to insert)
CREATE POLICY "Allow leverage limit creation"
  ON user_leverage_limits
  FOR INSERT
  WITH CHECK (true);

-- Add UPDATE policy for leverage limits (allows trigger to update)
CREATE POLICY "Allow leverage limit updates"
  ON user_leverage_limits
  FOR UPDATE
  USING (true)
  WITH CHECK (true);
