/*
  # Fix KYC + TrustPilot Bonus Default Amount

  ## Summary
  Updates the default_amount for the "KYC + TrustPilot Review Bonus" to 25 USDT.
  The bonus was showing as $0 in the admin panel, but should default to $25.

  ## Changes
  - Sets default_amount to 25 for the combined bonus type

  ## Security
  - No RLS changes needed
*/

UPDATE bonus_types
SET
  default_amount = 25,
  updated_at = now()
WHERE name = 'KYC + TrustPilot Review Bonus';
