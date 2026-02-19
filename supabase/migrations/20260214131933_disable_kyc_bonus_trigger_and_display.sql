/*
  # Disable KYC Bonus Trigger and Display Item

  1. Changes
    - Drops the trigger that auto-awards $20 KYC bonus on KYC approval
    - Deactivates the KYC Verification Bonus in reward_display_items
    - Deactivates the KYC Verification Bonus type so it cannot be awarded
  
  2. Important Notes
    - Existing bonuses already awarded are NOT affected
    - The bonus type remains in the database but is marked inactive
    - The trigger function is preserved but the trigger itself is removed
*/

-- Drop the trigger that awards KYC bonus on approval
DROP TRIGGER IF EXISTS trigger_award_kyc_bonus ON public.user_profiles;
DROP TRIGGER IF EXISTS tr_kyc_bonus_on_approval ON public.user_profiles;
DROP TRIGGER IF EXISTS tr_award_kyc_bonus_on_approval ON public.user_profiles;

-- Deactivate KYC Verification Bonus in reward_display_items
UPDATE public.reward_display_items
SET is_active = false
WHERE title = 'KYC Verification Bonus';

-- Deactivate the bonus type so it cannot be manually awarded either
UPDATE public.bonus_types
SET is_active = false
WHERE name = 'KYC Verification Bonus';
