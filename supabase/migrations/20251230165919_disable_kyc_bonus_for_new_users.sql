/*
  # Disable KYC Bonus for New Users

  1. Purpose
    - Stop awarding the 20 USDT KYC bonus to new users who complete KYC verification
    - Keep existing KYC bonuses intact for users who already received them
    - Remove the automatic trigger that awards bonuses on KYC approval

  2. Changes
    - Drop the trigger tr_kyc_bonus_on_approval from user_profiles table
    - This prevents future automatic bonus awards
    - Does not affect existing locked_bonuses records
*/

-- Drop the trigger that automatically awards KYC bonus on verification
DROP TRIGGER IF EXISTS tr_kyc_bonus_on_approval ON public.user_profiles;

-- Note: We keep the function in case it's needed for manual awards by admins
-- The function award_kyc_bonus() and tr_award_kyc_bonus_on_approval() remain in the database
-- but will no longer be automatically triggered
