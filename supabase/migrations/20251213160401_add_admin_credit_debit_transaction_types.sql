/*
  # Add Admin Credit/Debit Transaction Types

  1. Changes
    - Drop existing transaction_type constraint
    - Add new constraint including 'admin_credit' and 'admin_debit' types
    - Keep all existing types
*/

-- Drop existing constraint
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

-- Add updated constraint with admin_credit and admin_debit
ALTER TABLE transactions ADD CONSTRAINT transactions_transaction_type_check 
CHECK (transaction_type IN (
  'deposit',
  'withdraw',
  'withdrawal',
  'transfer',
  'reward',
  'fee_rebate',
  'swap',
  'stake',
  'unstake',
  'futures_open',
  'futures_close',
  'futures_liquidation',
  'futures_funding',
  'copy_trade_allocation',
  'copy_trade_close',
  'copy_withdrawal',
  'crypto_deposit',
  'admin_adjustment',
  'admin_credit',
  'admin_debit',
  'open_position',
  'close_position'
));
