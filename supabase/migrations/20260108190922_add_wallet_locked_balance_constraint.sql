/*
  # Add Wallet Balance Integrity Constraint

  1. Changes
    - Add CHECK constraint to prevent locked_balance from exceeding balance
    - Ensures data integrity going forward

  2. Security
    - No RLS changes needed
*/

-- Add check constraint to prevent locked_balance > balance
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'wallets_locked_balance_check'
  ) THEN
    ALTER TABLE wallets
    ADD CONSTRAINT wallets_locked_balance_check
    CHECK (locked_balance <= balance);
  END IF;
END $$;
