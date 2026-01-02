/*
  # Fix Existing Mock Copy Trading Initial Balances

  ## Problem
  Existing mock copy relationships have initial_balance = 0 because
  the function wasn't calculating it properly.

  ## Changes
  Update existing mock copy relationships to set initial_balance based on
  allocation_percentage * $10,000 demo balance.
*/

-- Update existing mock copy relationships with 0 initial balance
UPDATE copy_relationships
SET 
  initial_balance = 10000.0 * allocation_percentage / 100.0,
  current_balance = CASE 
    WHEN current_balance = 0 THEN 10000.0 * allocation_percentage / 100.0
    ELSE current_balance
  END,
  updated_at = NOW()
WHERE is_mock = true
  AND initial_balance = 0;
