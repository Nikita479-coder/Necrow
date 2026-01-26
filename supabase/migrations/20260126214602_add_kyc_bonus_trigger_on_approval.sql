/*
  # Add KYC Bonus Trigger on Approval

  1. Changes
    - Creates trigger to automatically award KYC bonus when kyc_status changes to 'verified'
    - Fires on user_profiles table update
*/

-- Drop if exists to recreate
DROP TRIGGER IF EXISTS trigger_award_kyc_bonus ON user_profiles;
DROP FUNCTION IF EXISTS tr_award_kyc_bonus_on_approval() CASCADE;

CREATE OR REPLACE FUNCTION tr_award_kyc_bonus_on_approval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Check if KYC status changed to verified
  IF NEW.kyc_status = 'verified' AND (OLD.kyc_status IS NULL OR OLD.kyc_status != 'verified') THEN
    -- Award the KYC bonus
    v_result := award_kyc_bonus(NEW.id);
    
    -- Log result for debugging
    IF NOT (v_result->>'success')::boolean THEN
      RAISE WARNING 'KYC bonus award failed for user %: %', NEW.id, v_result->>'error';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_award_kyc_bonus
  AFTER UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION tr_award_kyc_bonus_on_approval();
