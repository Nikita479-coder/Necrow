/*
  # Create New Copy Trading Wallet Bonus V2

  1. New Bonus Type
    - Creates a completely new "Copy Trading Wallet Bonus V2" separate from the original
    - Users who claimed the old bonus can now claim this new one
    - Same conditions: Move 500 USDT to Copy Trading, locked 30 days, keep bonus + profits

  2. Details
    - Bonus amount: 100 USDT
    - Locked for 30 days
    - Category: promotion
    - Requires 500 USDT allocation to Copy Trading wallet
*/

INSERT INTO bonus_types (
  id,
  name,
  description,
  default_amount,
  category,
  expiry_days,
  is_active,
  is_locked_bonus,
  allowed_countries,
  excluded_countries
) VALUES (
  gen_random_uuid(),
  'Copy Trading Wallet Bonus V2',
  'NEW: Move 500 USDT to Copy Trading wallet - locked 30 days, keep bonus + profits after. This is a new bonus separate from the original.',
  100.00,
  'promotion',
  30,
  true,
  true,
  NULL,
  NULL
);
