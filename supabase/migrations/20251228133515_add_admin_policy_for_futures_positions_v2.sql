/*
  # Add Admin Policy for Futures Positions

  1. Changes
    - Add SELECT policy for admins to view all futures positions
    - Add UPDATE policy for admins to update any futures position

  2. Security
    - Only users with is_admin=true in user_profiles can access all positions
    - Regular users can only see their own positions (existing policies remain)
*/

-- Add admin SELECT policy for futures_positions
DROP POLICY IF EXISTS "Admins can view all positions" ON futures_positions;
CREATE POLICY "Admins can view all positions"
  ON futures_positions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
      AND is_admin = true
    )
  );

-- Add admin UPDATE policy for futures_positions
DROP POLICY IF EXISTS "Admins can update all positions" ON futures_positions;
CREATE POLICY "Admins can update all positions"
  ON futures_positions
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
      AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
      AND is_admin = true
    )
  );