/*
  # Add Referral Transaction Types

  ## Summary
  Adds 'referral_commission' and 'referral_rebate' to the allowed transaction types.

  ## Changes
  1. Drops existing transaction_type check constraint
  2. Recreates constraint with referral types included
*/

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

ALTER TABLE transactions ADD CONSTRAINT transactions_transaction_type_check 
CHECK (transaction_type IN (
  'deposit', 'withdrawal', 'transfer', 'swap', 'stake', 'unstake',
  'reward', 'fee_rebate', 'referral_commission', 'referral_rebate',
  'futures_open', 'futures_close', 'open_position', 'close_position',
  'copy_trade_allocation', 'copy_trade_close', 'admin_adjustment',
  'admin_credit', 'admin_debit', 'liquidation', 'funding_fee',
  'locked_trading_bonus', 'bonus'
));
