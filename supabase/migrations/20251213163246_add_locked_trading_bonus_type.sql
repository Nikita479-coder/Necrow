/*
  # Add Locked Trading Bonus Type

  ## Summary
  Adds a default locked trading bonus type that admins can use to award
  non-withdrawable trading bonuses with 7-day expiry.

  ## New Bonus Type
  - "Locked Trading Bonus" - A bonus that can only be used for futures trading
  - Default amount: $100
  - Default expiry: 7 days
  - Category: trading
  - is_locked_bonus: true
*/

INSERT INTO bonus_types (name, description, default_amount, category, expiry_days, is_active, is_locked_bonus)
VALUES (
  'Locked Trading Bonus',
  'A non-withdrawable bonus that can be used for futures trading. Profits from trading with this bonus are withdrawable. The bonus itself expires after the set period.',
  100.00,
  'trading',
  7,
  true,
  true
)
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  is_locked_bonus = true,
  expiry_days = COALESCE(bonus_types.expiry_days, 7);

INSERT INTO bonus_types (name, description, default_amount, category, expiry_days, is_active, is_locked_bonus)
VALUES (
  'Welcome Locked Bonus',
  'A locked welcome bonus for new users. Can be used for futures trading. Profits are yours to keep but the bonus expires after 10 days.',
  50.00,
  'welcome',
  10,
  true,
  true
)
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  is_locked_bonus = true,
  expiry_days = COALESCE(bonus_types.expiry_days, 10);
