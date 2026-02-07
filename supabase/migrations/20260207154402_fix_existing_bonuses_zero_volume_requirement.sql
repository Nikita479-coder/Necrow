/*
  # Fix Existing Bonuses with $0 Volume Requirement

  ## Problem
  66 bonuses were created with bonus_trading_volume_required = 0 due to a bug
  in the award_first_deposit_bonus function. This caused users to receive 
  "Bonus Ready to Unlock!" notifications after minimal trading.

  ## Solution
  1. Update all ACTIVE bonuses with $0 requirement to have proper requirements
  2. Set bonus_trading_volume_required = original_amount * 500
  3. Set minimum_position_duration_minutes = 10 if not set

  ## Affected Bonus Types
  - KYC Verification Bonus: 55 bonuses
  - First Deposit Match Bonus: 7 bonuses
  - Trustpilot Review Bonus: 3 bonuses
  - First Trade Bonus: 1 bonus
*/

UPDATE locked_bonuses
SET 
  bonus_trading_volume_required = original_amount * 500,
  minimum_position_duration_minutes = COALESCE(minimum_position_duration_minutes, 10)
WHERE bonus_trading_volume_required = 0
  AND status = 'active';

UPDATE locked_bonuses
SET 
  bonus_trading_volume_required = original_amount * 500,
  minimum_position_duration_minutes = COALESCE(minimum_position_duration_minutes, 10)
WHERE bonus_trading_volume_required IS NULL
  AND status = 'active';
