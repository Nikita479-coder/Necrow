/*
  # Create Referral Locked Bonus Types

  1. New Data
    - "First Referral Bonus" - $5 locked bonus for first qualified referral
    - "Growing Network Bonus" - $25 locked bonus for 5 qualified referrals

  2. Purpose
    - Rewards users for bringing active traders
    - Referrals must deposit $100+ to qualify
    - 7-day lock period by default
*/

INSERT INTO bonus_types (name, description, default_amount, is_locked_bonus, expiry_days, category)
VALUES (
  'First Referral Bonus',
  'Locked bonus for bringing your first active trader who deposits $100+',
  5,
  true,
  7,
  'referral'
)
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  default_amount = EXCLUDED.default_amount,
  is_locked_bonus = EXCLUDED.is_locked_bonus,
  expiry_days = EXCLUDED.expiry_days;

INSERT INTO bonus_types (name, description, default_amount, is_locked_bonus, expiry_days, category)
VALUES (
  'Growing Network Bonus',
  'Locked bonus for inviting 5 friends who each deposit $100+',
  25,
  true,
  7,
  'referral'
)
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  default_amount = EXCLUDED.default_amount,
  is_locked_bonus = EXCLUDED.is_locked_bonus,
  expiry_days = EXCLUDED.expiry_days;
