/*
  # Fix Transactions RLS Policies

  1. Changes
    - Remove duplicate SELECT policy
    - Simplify RLS policy to use auth.uid() directly
    - This fixes the bug where transactions were not loading
*/

-- Drop existing SELECT policies
DROP POLICY IF EXISTS "Users can read own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can view own transactions" ON transactions;

-- Create single optimized SELECT policy
CREATE POLICY "Users can view own transactions"
  ON transactions
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Also ensure admin can view all transactions
DROP POLICY IF EXISTS "Admins can view all transactions" ON transactions;

CREATE POLICY "Admins can view all transactions"
  ON transactions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );
