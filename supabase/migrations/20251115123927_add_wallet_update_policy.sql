/*
  # Add Wallet Update Policy

  ## Description
  Adds the missing UPDATE policy for the wallets table. Without this policy,
  swap functions and other operations cannot update wallet balances even though
  they can read and insert.

  ## Changes
  - Add UPDATE policy for authenticated users to update their own wallets

  ## Security
  - Users can only update their own wallets (where auth.uid() = user_id)
  - This is required for swap operations, deposits, withdrawals, and transfers
*/

CREATE POLICY "Users can update own wallets"
  ON wallets FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);