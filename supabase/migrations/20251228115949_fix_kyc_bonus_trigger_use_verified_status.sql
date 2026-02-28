/*
  # Fix KYC Bonus Trigger to Use 'verified' Status

  1. Issue
    - The trigger was checking for kyc_status = 'approved'
    - But the check constraint only allows 'unverified', 'pending', 'verified', 'rejected'
    - This means the trigger never fires and bonuses never get awarded

  2. Fix
    - Update the trigger function to check for kyc_status = 'verified' instead
    - Now bonuses will be awarded when users are verified
*/

-- Update trigger function to check for 'verified' instead of 'approved'
CREATE OR REPLACE FUNCTION public.tr_award_kyc_bonus_on_approval()
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
    v_result := public.award_kyc_bonus(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;
