/*
  # Fix Transactions Constraints for Swap

  ## Description
  Updates the transactions table constraints to:
  1. Allow 'swap' as a valid transaction_type
  2. Remove amount check constraint that prevents negative amounts (or keep positive only)

  ## Changes
  - Drop existing transaction_type check constraint
  - Add new constraint that includes 'swap' type
  - Keep amount constraint as positive only (swap functions updated to use positive amounts)

  ## Important
  - Swap transactions will use positive amounts with proper transaction_type
*/

-- Drop existing transaction_type constraint
ALTER TABLE transactions 
DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

-- Add new constraint with 'swap' included
ALTER TABLE transactions
ADD CONSTRAINT transactions_transaction_type_check 
CHECK (transaction_type = ANY (ARRAY[
  'deposit'::text, 
  'withdrawal'::text, 
  'transfer'::text, 
  'reward'::text, 
  'fee_rebate'::text,
  'swap'::text
]));