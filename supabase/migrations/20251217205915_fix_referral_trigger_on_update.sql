/*
  # Fix referral trigger to fire on UPDATE

  1. Problem
    - The build_affiliate_chain trigger only fires on INSERT
    - But referred_by is set via UPDATE after the profile is created
    
  2. Solution
    - Drop the existing INSERT-only trigger
    - Create a new trigger that fires on both INSERT and UPDATE of referred_by
    - Update the function to handle UPDATE case correctly
*/

-- Drop existing trigger
DROP TRIGGER IF EXISTS trigger_build_affiliate_chain ON user_profiles;

-- Update function to handle both INSERT and UPDATE
CREATE OR REPLACE FUNCTION build_affiliate_chain()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_referrer_id UUID;
  v_tier INTEGER := 1;
  v_direct_referrer_id UUID;
  v_referred_by UUID;
BEGIN
  -- Determine which referred_by to use
  IF TG_OP = 'INSERT' THEN
    v_referred_by := NEW.referred_by;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Only process if referred_by changed from NULL to a value
    IF OLD.referred_by IS NULL AND NEW.referred_by IS NOT NULL THEN
      v_referred_by := NEW.referred_by;
    ELSE
      -- referred_by didn't change or was already set, skip
      RETURN NEW;
    END IF;
  END IF;

  IF v_referred_by IS NULL THEN
    RETURN NEW;
  END IF;

  v_current_referrer_id := v_referred_by;
  v_direct_referrer_id := v_referred_by;

  WHILE v_current_referrer_id IS NOT NULL AND v_tier <= 5 LOOP
    INSERT INTO affiliate_tiers (affiliate_id, referral_id, tier_level, direct_referrer_id)
    VALUES (v_current_referrer_id, NEW.id, v_tier, v_direct_referrer_id)
    ON CONFLICT (affiliate_id, referral_id) DO NOTHING;

    -- Ensure referral_stats record exists for the referrer
    INSERT INTO referral_stats (user_id, vip_level, total_volume_30d, total_referrals, total_earnings)
    VALUES (v_current_referrer_id, 1, 0, 0, 0)
    ON CONFLICT (user_id) DO NOTHING;

    IF v_tier = 1 THEN
      -- Update total_referrals for direct referrer (tier 1)
      UPDATE referral_stats
      SET 
        total_referrals = COALESCE(total_referrals, 0) + 1,
        updated_at = now()
      WHERE user_id = v_current_referrer_id;
    ELSE
      -- Update tier 2-5 referral counts
      UPDATE referral_stats
      SET 
        tier_2_referrals = CASE WHEN v_tier = 2 THEN COALESCE(tier_2_referrals, 0) + 1 ELSE tier_2_referrals END,
        tier_3_referrals = CASE WHEN v_tier = 3 THEN COALESCE(tier_3_referrals, 0) + 1 ELSE tier_3_referrals END,
        tier_4_referrals = CASE WHEN v_tier = 4 THEN COALESCE(tier_4_referrals, 0) + 1 ELSE tier_4_referrals END,
        tier_5_referrals = CASE WHEN v_tier = 5 THEN COALESCE(tier_5_referrals, 0) + 1 ELSE tier_5_referrals END,
        updated_at = now()
      WHERE user_id = v_current_referrer_id;
    END IF;

    -- Get the next referrer in the chain
    SELECT up.referred_by INTO v_current_referrer_id
    FROM user_profiles up
    WHERE up.id = v_current_referrer_id;

    v_tier := v_tier + 1;
  END LOOP;

  RETURN NEW;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NEW;
  WHEN TOO_MANY_ROWS THEN
    RETURN NEW;
END;
$$;

-- Create new trigger that fires on both INSERT and UPDATE
CREATE TRIGGER trigger_build_affiliate_chain
  AFTER INSERT OR UPDATE OF referred_by ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION build_affiliate_chain();
