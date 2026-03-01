/*
  # Award KYC Bonuses to Verified Users (v3)

  1. Purpose
    - Award the $20 KYC bonus to users who are verified at level 2
    - But haven't received the bonus yet

  2. Changes
    - Find users with kyc_level = 2 and kyc_status = 'verified'
    - Who don't have a KYC bonus already awarded
    - Manually call award_kyc_bonus for each of them
*/

-- Award bonuses to users who are verified at level 2 but haven't received the bonus
DO $$
DECLARE
  v_user RECORD;
  v_result jsonb;
BEGIN
  FOR v_user IN 
    SELECT up.id, up.username, up.full_name
    FROM user_profiles up
    LEFT JOIN signup_bonus_tracking sbt ON sbt.user_id = up.id
    WHERE up.kyc_level = 2 
      AND up.kyc_status = 'verified'
      AND (sbt.kyc_bonus_awarded IS NULL OR sbt.kyc_bonus_awarded = false)
  LOOP
    -- Award the KYC bonus
    v_result := public.award_kyc_bonus(v_user.id);
    RAISE NOTICE 'User: % (%) - Result: %', v_user.full_name, v_user.username, v_result;
  END LOOP;
END $$;
