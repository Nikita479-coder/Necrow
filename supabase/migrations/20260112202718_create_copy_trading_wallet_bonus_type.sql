/*
  # Create Copy Trading Wallet Bonus Type

  1. New Data
    - Creates a specific "Copy Trading Wallet Bonus" type
    - 30-day lock period (expiry_days: 30)
    - is_locked_bonus: true

  2. Purpose
    - Users get $100 bonus when they allocate 500 USDT to copy trading
    - Bonus is locked for 30 days
    - User keeps bonus + profits after lock period
*/

INSERT INTO bonus_types (name, description, default_amount, is_locked_bonus, expiry_days, category)
VALUES (
  'Copy Trading Wallet Bonus',
  'Locked bonus for allocating 500 USDT to Copy Trading wallet - keep bonus + profits after 30 days',
  100,
  true,
  30,
  'promotion'
)
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  default_amount = EXCLUDED.default_amount,
  is_locked_bonus = EXCLUDED.is_locked_bonus,
  expiry_days = EXCLUDED.expiry_days;
