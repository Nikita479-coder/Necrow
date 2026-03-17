/*
  # Update Transactions Table to Support Reward Types

  1. Changes
    - Drop existing transaction_type check constraint
    - Add new constraint that includes 'reward' and 'fee_rebate' types
    - This allows the system to record reward claims in transaction history

  2. Notes
    - Maintains backward compatibility with existing 'deposit' and 'withdrawal' types
    - Enables proper transaction tracking for the rewards system
*/

-- Drop the old constraint
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

-- Add new constraint with reward types
ALTER TABLE transactions 
ADD CONSTRAINT transactions_transaction_type_check 
CHECK (transaction_type = ANY (ARRAY['deposit'::text, 'withdrawal'::text, 'reward'::text, 'fee_rebate'::text]));
