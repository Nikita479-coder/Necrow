/*
  # Create Combined KYC + TrustPilot Bonus Type

  ## Summary
  Creates a new $25 bonus type that combines KYC verification and TrustPilot review.
  Deactivates the old separate KYC ($20) and TrustPilot ($5) bonus types.
  
  ## New Bonus Type
  - Name: "KYC + TrustPilot Review Bonus"
  - Amount: $25 USDT
  - Expiry: 30 days
  - Requirements:
    - KYC verification completed
    - 5-star TrustPilot review submitted
    - 30 consecutive trading days (2 trades per day, 15+ min each)
    - 500x volume ($12,500)

  ## Changes
  - Deactivates "KYC Verification Bonus" (is_active = false)
  - Deactivates "Trustpilot Review Bonus" (is_active = false)
  - Existing active bonuses under old types continue under old rules

  ## Security
  - Only admins can award this bonus type
*/

-- Deactivate old KYC Verification Bonus type (keep for existing bonuses)
UPDATE bonus_types
SET 
  is_active = false,
  updated_at = now()
WHERE name = 'KYC Verification Bonus';

-- Deactivate old Trustpilot Review Bonus type (keep for existing bonuses)
UPDATE bonus_types
SET 
  is_active = false,
  updated_at = now()
WHERE name = 'Trustpilot Review Bonus';

-- Create the new combined bonus type
INSERT INTO bonus_types (
  id,
  name,
  description,
  default_amount,
  category,
  expiry_days,
  is_active,
  is_locked_bonus,
  created_at,
  updated_at
)
VALUES (
  gen_random_uuid(),
  'KYC + TrustPilot Review Bonus',
  '$25 bonus for completing KYC verification and leaving a 5-star TrustPilot review. Requires 30 consecutive trading days.',
  25,
  'promotion',
  30,
  true,
  true,
  now(),
  now()
)
ON CONFLICT DO NOTHING;

-- Add comment explaining the new bonus
COMMENT ON TABLE bonus_types IS 'Bonus type definitions. The KYC + TrustPilot Review Bonus combines the old separate bonuses into one $25 bonus with stricter requirements.';
