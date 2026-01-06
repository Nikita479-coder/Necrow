/*
  # Create Reward Task Bonus Type

  1. New Data
    - Creates a generic "Reward Task Bonus" type for all reward hub tasks
    - Used when users claim locked bonus rewards from completing tasks
  
  2. Configuration
    - is_locked_bonus: true (bonus goes to locked bonus balance)
    - expiry_days: 7 (7 day expiry)
    - category: promotion
*/

INSERT INTO bonus_types (name, description, default_amount, is_locked_bonus, expiry_days, category)
VALUES (
  'Reward Task Bonus',
  'Locked bonus earned from completing reward hub tasks',
  0,
  true,
  7,
  'promotion'
)
ON CONFLICT (name) DO NOTHING;
