/*
  # Add Staking Transaction Types

  ## Summary
  Updates the transactions table to support staking-related transaction types.

  ## Changes
  - Add 'stake' transaction type for staking tokens
  - Add 'unstake' transaction type for unstaking tokens
  - Keep all existing transaction types

  ## Transaction Types After Update
  - deposit: Depositing funds into wallet
  - withdrawal: Withdrawing funds from wallet
  - transfer: Transferring between wallets
  - reward: Reward payments
  - fee_rebate: Fee rebates
  - swap: Token swaps
  - stake: Staking tokens (NEW)
  - unstake: Unstaking tokens (NEW)
*/

-- Drop the existing constraint
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

-- Add the updated constraint with staking types
ALTER TABLE transactions ADD CONSTRAINT transactions_transaction_type_check 
  CHECK (transaction_type = ANY (ARRAY[
    'deposit'::text, 
    'withdrawal'::text, 
    'transfer'::text, 
    'reward'::text, 
    'fee_rebate'::text, 
    'swap'::text,
    'stake'::text,
    'unstake'::text
  ]));
