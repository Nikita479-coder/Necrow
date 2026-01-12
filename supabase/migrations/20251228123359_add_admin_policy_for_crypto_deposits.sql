/*
  # Add Admin Policy for Crypto Deposits

  ## Summary
  Adds RLS policy to allow super admins to view all crypto deposits in the admin panel.

  ## Changes
  - Add policy for admins to SELECT all crypto_deposits records

  ## Security
  - Policy checks if user has is_admin=true in user_profiles
  - Only affects SELECT operations
  - Maintains existing user policies
*/

-- Add admin policy to view all deposits
CREATE POLICY "Admins can view all deposits"
  ON crypto_deposits FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );
