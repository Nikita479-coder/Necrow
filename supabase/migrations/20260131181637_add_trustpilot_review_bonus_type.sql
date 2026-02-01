/*
  # Add Trustpilot Review Bonus Type

  ## New Bonus Type
  - Trustpilot Review Bonus - $5 locked bonus for leaving a 5-star review
  - Category: trading (requires volume to unlock)
  - Standard 7-day expiry
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
  created_at
)
VALUES (
  gen_random_uuid(),
  'Trustpilot Review Bonus',
  '$5 bonus for leaving a 5-star Trustpilot review',
  5,
  'trading',
  7,
  true,
  true,
  now()
)
ON CONFLICT DO NOTHING;
