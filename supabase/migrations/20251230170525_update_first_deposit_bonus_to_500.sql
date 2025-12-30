/*
  # Update First Deposit Bonus to $500 Cap

  ## Summary
  Updates the First Deposit Match Bonus to provide a 100% match up to $500 USD (instead of $100).
  This gives new users a more generous welcome bonus to start trading.

  ## Changes
  - Update default_amount from $100 to $500
  - Update description to reflect new cap
  - Keep expiry at 7 days
  - Keep as active locked bonus

  ## Bonus Details
  - Type: Locked Trading Bonus
  - Amount: 100% match up to $500
  - Validity: 7 days
  - Usage: Futures trading only
  - Withdrawal: Only profits can be withdrawn
  - Unlock: Through trading volume requirements
*/

UPDATE bonus_types
SET
  default_amount = 500.00,
  description = '100% match on your first deposit, up to $500. Valid for 7 days. Only profits can be withdrawn.'
WHERE name = 'First Deposit Match Bonus';
