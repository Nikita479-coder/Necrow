/*
  # Fix has_exclusive_affiliate_in_upline to Detect All Exclusive Affiliates
  
  1. Changes
    - Remove is_active check from has_exclusive_affiliate_in_upline function
    - Once enrolled as exclusive affiliate, all referrals should go through exclusive system
    - Increase max depth to 10 levels to match exclusive affiliate tier depth
    
  2. Reason
    - A112SH has is_active = false but should still receive exclusive commissions
    - Regular affiliate commissions should not be distributed when ANY exclusive
      affiliate exists in the upline chain (active or not)
*/

CREATE OR REPLACE FUNCTION has_exclusive_affiliate_in_upline(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user uuid := p_user_id;
  v_referrer_id uuid;
  v_level integer := 1;
BEGIN
  -- Check up to 10 levels (matching exclusive affiliate tier depth)
  WHILE v_level <= 10 LOOP
    SELECT referred_by INTO v_referrer_id
    FROM user_profiles
    WHERE id = v_current_user;

    IF v_referrer_id IS NULL THEN
      RETURN false;
    END IF;

    -- Check if referrer is ANY exclusive affiliate (regardless of is_active status)
    IF EXISTS (
      SELECT 1 FROM exclusive_affiliates
      WHERE user_id = v_referrer_id
    ) THEN
      RETURN true;
    END IF;

    v_current_user := v_referrer_id;
    v_level := v_level + 1;
  END LOOP;

  RETURN false;
END;
$$;
