/*
  # Create Network Champion Bonus type

  1. Problem
    - The Rewards Hub references a bonus type named "Network Champion Bonus"
      but it does not exist in the `bonus_types` table, causing a
      "Bonus type not found" error when users try to claim it.

  2. Fix
    - Insert the missing bonus type with $70 amount as a locked bonus,
      matching the reward display configuration.
*/

INSERT INTO bonus_types (name, description, default_amount, category, expiry_days, is_active, is_locked_bonus)
VALUES (
  'Network Champion Bonus',
  'Locked bonus awarded for inviting 10 friends who each deposit $100+',
  70.00,
  'referral',
  7,
  true,
  true
)
ON CONFLICT DO NOTHING;
