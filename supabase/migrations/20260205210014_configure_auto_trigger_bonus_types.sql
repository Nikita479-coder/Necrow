/*
  # Configure Auto-Trigger Bonus Types

  1. Changes
    - Deactivates "KYC + TrustPilot Review Bonus" ($25 combined) -- replaced by separate bonuses
    - Re-activates "KYC Verification Bonus" as $20 locked bonus, 7-day expiry, auto-triggered on kyc_verified
    - Updates "Trustpilot Review Bonus" as $5 locked bonus, 7-day expiry (manual claim, not auto-triggered)
    - Also updates the other Trustpilot ($5) entry to be inactive since the proper one is now active
    - Configures deposit bonus types with auto-trigger for first/second/third deposit

  2. Security
    - No RLS changes
    - No destructive operations

  3. Important Notes
    - The $25 combined bonus is deactivated, not deleted, to preserve history
    - KYC bonus now fires automatically via database trigger (configured in next migration)
    - Deposit bonuses now fire automatically when deposits complete
    - TrustPilot bonus remains manual (admin awards after verifying review)
*/

-- 1. Deactivate the combined $25 KYC + TrustPilot bonus
UPDATE bonus_types
SET is_active = false, updated_at = now()
WHERE name = 'KYC + TrustPilot Review Bonus';

-- 2. Re-activate KYC Verification Bonus as $20 locked, 7-day, auto-triggered
UPDATE bonus_types
SET
  is_active = true,
  default_amount = 20,
  is_locked_bonus = true,
  expiry_days = 7,
  auto_trigger_event = 'kyc_verified',
  auto_trigger_enabled = true,
  description = 'Automatically awarded when KYC verification is approved. Locked trading bonus - profits are withdrawable.',
  updated_at = now()
WHERE name = 'KYC Verification Bonus';

-- 3. Activate the proper Trustpilot Review Bonus as $5 locked, 7-day, manual
UPDATE bonus_types
SET
  is_active = true,
  default_amount = 5,
  is_locked_bonus = true,
  expiry_days = 7,
  category = 'promotion',
  auto_trigger_event = 'trustpilot_review',
  auto_trigger_enabled = false,
  description = 'Awarded after admin verifies a genuine 5-star TrustPilot review. Locked trading bonus - profits are withdrawable.',
  updated_at = now()
WHERE id = '9f688fd4-c116-4cd1-9ec6-6c191dd7cf3e';

-- Deactivate the duplicate "Trustpilot Review ($5)" entry
UPDATE bonus_types
SET is_active = false, updated_at = now()
WHERE id = 'ff9b6a32-65b1-4fbe-ba9e-7cdefad88eff';

-- 4. Configure First Deposit Bonus as auto-triggered
UPDATE bonus_types
SET
  is_locked_bonus = true,
  expiry_days = 7,
  auto_trigger_event = 'first_deposit',
  auto_trigger_enabled = true,
  auto_trigger_config = jsonb_build_object(
    'bonus_percentage', 100,
    'max_amount', 500,
    'min_deposit', 10
  ),
  description = 'Automatically awarded on first qualifying deposit. 100% match up to $500. Locked trading bonus - profits are withdrawable.',
  updated_at = now()
WHERE name = 'First Deposit Bonus';

-- Also update the "First Deposit Match Bonus" (inactive duplicate) to stay inactive
UPDATE bonus_types
SET auto_trigger_enabled = false, updated_at = now()
WHERE name = 'First Deposit Match Bonus';

-- 5. Configure Second Deposit Bonus as auto-triggered
UPDATE bonus_types
SET
  expiry_days = 7,
  auto_trigger_event = 'second_deposit',
  auto_trigger_enabled = true,
  auto_trigger_config = jsonb_build_object(
    'bonus_percentage', 50,
    'max_amount', 500,
    'min_deposit', 10
  ),
  description = 'Automatically awarded on second qualifying deposit. 50% match up to $500. Locked trading bonus - profits are withdrawable.',
  updated_at = now()
WHERE name = 'Second Deposit Bonus';

-- 6. Configure Third Deposit Bonus as auto-triggered
UPDATE bonus_types
SET
  expiry_days = 7,
  auto_trigger_event = 'third_deposit',
  auto_trigger_enabled = true,
  auto_trigger_config = jsonb_build_object(
    'bonus_percentage', 20,
    'max_amount', 610,
    'min_deposit', 10
  ),
  description = 'Automatically awarded on third qualifying deposit. 20% match up to $610. Locked trading bonus - profits are withdrawable.',
  updated_at = now()
WHERE name = 'Third Deposit Bonus';
