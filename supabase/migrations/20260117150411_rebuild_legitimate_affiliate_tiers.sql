/*
  # Rebuild Legitimate Affiliate Tiers

  ## Issue
  The cleanup query removed some legitimate affiliate_tiers entries
  including a112sh's legitimate tier 3 entry for garamara870
  
  ## Solution
  Rebuild all affiliate_tiers from scratch based on actual referral chains
*/

-- Rebuild all affiliate_tiers by simulating the referral signup process
-- First, let's rebuild missing entries for all users
DO $$
DECLARE
  v_user RECORD;
  v_current_referrer_id UUID;
  v_tier INTEGER;
  v_direct_referrer_id UUID;
BEGIN
  -- Loop through all users who have a referrer
  FOR v_user IN (
    SELECT id, referred_by 
    FROM user_profiles 
    WHERE referred_by IS NOT NULL
    ORDER BY created_at
  ) LOOP
    v_current_referrer_id := v_user.referred_by;
    v_direct_referrer_id := v_user.referred_by;
    v_tier := 1;
    
    -- Build the affiliate chain
    WHILE v_current_referrer_id IS NOT NULL AND v_tier <= 5 LOOP
      -- Insert affiliate tier (skip if already exists)
      INSERT INTO affiliate_tiers (affiliate_id, referral_id, tier_level, direct_referrer_id)
      VALUES (v_current_referrer_id, v_user.id, v_tier, v_direct_referrer_id)
      ON CONFLICT (affiliate_id, referral_id) DO NOTHING;
      
      -- Get next referrer in chain
      SELECT up.referred_by INTO v_current_referrer_id
      FROM user_profiles up
      WHERE up.id = v_current_referrer_id;
      
      v_tier := v_tier + 1;
    END LOOP;
  END LOOP;
END $$;
