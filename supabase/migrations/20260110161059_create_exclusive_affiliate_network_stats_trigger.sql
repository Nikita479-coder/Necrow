/*
  # Auto-Update Exclusive Affiliate Network Stats

  ## Overview
  Creates a trigger to automatically update exclusive affiliate network stats
  when new users sign up with a referral code.

  ## Changes
  1. Creates function to recalculate network stats for all exclusive affiliates
     in a user's upline chain
  2. Creates trigger on user_profiles to call this function on INSERT

  ## Security
  - Uses SECURITY DEFINER with restricted search_path
*/

CREATE OR REPLACE FUNCTION update_exclusive_affiliate_network_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id uuid;
  v_current_id uuid;
  v_level int := 1;
BEGIN
  IF NEW.referred_by IS NULL THEN
    RETURN NEW;
  END IF;
  
  v_current_id := NEW.referred_by;
  
  WHILE v_current_id IS NOT NULL AND v_level <= 5 LOOP
    IF EXISTS (
      SELECT 1 FROM exclusive_affiliates 
      WHERE user_id = v_current_id AND is_active = true
    ) THEN
      UPDATE exclusive_affiliate_network_stats
      SET 
        level_1_count = CASE WHEN v_level = 1 THEN level_1_count + 1 ELSE level_1_count END,
        level_2_count = CASE WHEN v_level = 2 THEN level_2_count + 1 ELSE level_2_count END,
        level_3_count = CASE WHEN v_level = 3 THEN level_3_count + 1 ELSE level_3_count END,
        level_4_count = CASE WHEN v_level = 4 THEN level_4_count + 1 ELSE level_4_count END,
        level_5_count = CASE WHEN v_level = 5 THEN level_5_count + 1 ELSE level_5_count END,
        updated_at = NOW()
      WHERE affiliate_id = v_current_id;
    END IF;
    
    SELECT referred_by INTO v_referrer_id
    FROM user_profiles
    WHERE id = v_current_id;
    
    v_current_id := v_referrer_id;
    v_level := v_level + 1;
  END LOOP;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_exclusive_affiliate_network_stats ON user_profiles;

CREATE TRIGGER trg_update_exclusive_affiliate_network_stats
AFTER INSERT ON user_profiles
FOR EACH ROW
EXECUTE FUNCTION update_exclusive_affiliate_network_stats();
