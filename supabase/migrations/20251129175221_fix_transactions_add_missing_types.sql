/*
  # Fix Transactions Constraint - Add Missing Transaction Types

  1. Changes
    - Drop old constraint
    - Add new constraint with all transaction types including futures trading types
*/

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

ALTER TABLE transactions ADD CONSTRAINT transactions_transaction_type_check 
CHECK (transaction_type IN (
  'deposit',
  'withdraw',
  'withdrawal',
  'transfer',
  'reward',
  'fee_rebate',
  'referral_commission',
  'swap',
  'stake',
  'unstake',
  'open_position',
  'close_position',
  'futures_trade',
  'copy_trade_pnl'
));