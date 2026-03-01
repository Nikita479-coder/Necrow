/*
  # CPA Tracking and Network Functions

  ## Functions
  1. `qualify_cpa_payout` - Handles CPA qualification events
  2. `get_affiliate_network` - Returns full affiliate network tree
  3. `get_sub_affiliates` - Returns sub-affiliates for a user
  4. `get_tier_breakdown` - Detailed tier breakdown with user info

  ## CPA Qualification Types
  - signup: When user completes registration (usually $0)
  - kyc_verified: When user completes KYC
  - first_deposit: When user makes first deposit
  - first_trade: When user completes first trade
  - volume_threshold: When user reaches trading volume threshold
*/

-- Qualify CPA payout
CREATE OR REPLACE FUNCTION qualify_cpa_payout(
  p_referred_user_id UUID,
  p_qualification_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_cpa_amount NUMERIC;
  v_compensation_plan TEXT;
  v_existing_cpa RECORD;
BEGIN
  SELECT referred_by INTO v_referrer_id
  FROM user_profiles
  WHERE id = p_referred_user_id;

  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User was not referred');
  END IF;

  SELECT COALESCE(plan_type, 'revshare') INTO v_compensation_plan
  FROM affiliate_compensation_plans
  WHERE user_id = v_referrer_id;

  IF v_compensation_plan NOT IN ('cpa', 'hybrid') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Referrer not on CPA plan');
  END IF;

  SELECT * INTO v_existing_cpa
  FROM cpa_payouts
  WHERE referred_user_id = p_referred_user_id;

  IF v_existing_cpa.id IS NOT NULL AND v_existing_cpa.status IN ('qualified', 'paid') THEN
    RETURN jsonb_build_object('success', false, 'error', 'CPA already paid');
  END IF;

  v_cpa_amount := CASE p_qualification_type
    WHEN 'signup' THEN 0
    WHEN 'kyc_verified' THEN 10
    WHEN 'first_deposit' THEN 25
    WHEN 'first_trade' THEN 50
    WHEN 'volume_threshold' THEN 100
    ELSE 0
  END;

  IF v_cpa_amount = 0 AND p_qualification_type != 'signup' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid qualification type');
  END IF;

  IF v_existing_cpa.id IS NOT NULL THEN
    UPDATE cpa_payouts
    SET 
      qualification_type = p_qualification_type,
      cpa_amount = v_cpa_amount,
      qualification_met_at = now(),
      status = 'qualified'
    WHERE id = v_existing_cpa.id;
  ELSE
    INSERT INTO cpa_payouts (
      affiliate_id, referred_user_id, cpa_amount, 
      qualification_type, qualification_met_at, status
    ) VALUES (
      v_referrer_id, p_referred_user_id, v_cpa_amount,
      p_qualification_type, now(), CASE WHEN v_cpa_amount > 0 THEN 'qualified' ELSE 'pending' END
    );
  END IF;

  IF v_cpa_amount > 0 THEN
    UPDATE wallets
    SET balance = balance + v_cpa_amount, updated_at = now()
    WHERE user_id = v_referrer_id AND currency = 'USDT' AND wallet_type = 'main';

    UPDATE referral_stats
    SET 
      cpa_earnings = COALESCE(cpa_earnings, 0) + v_cpa_amount,
      lifetime_earnings = COALESCE(lifetime_earnings, 0) + v_cpa_amount,
      updated_at = now()
    WHERE user_id = v_referrer_id;

    INSERT INTO notifications (user_id, type, title, message, data)
    VALUES (
      v_referrer_id,
      'referral_payout',
      'CPA Bonus Earned!',
      'You earned $' || v_cpa_amount::TEXT || ' USDT for your referral reaching ' || p_qualification_type,
      jsonb_build_object('amount', v_cpa_amount, 'type', 'cpa', 'qualification', p_qualification_type)
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'cpa_amount', v_cpa_amount,
    'qualification_type', p_qualification_type
  );
END;
$$;

-- Get full affiliate network tree
CREATE OR REPLACE FUNCTION get_affiliate_network(p_user_id UUID)
RETURNS TABLE(
  user_id UUID,
  username TEXT,
  email_masked TEXT,
  tier_level INTEGER,
  vip_level INTEGER,
  joined_at TIMESTAMPTZ,
  total_volume NUMERIC,
  commission_earned NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    at.referral_id as user_id,
    COALESCE(up.username, 'User') as username,
    CASE 
      WHEN au.email IS NOT NULL THEN 
        SUBSTRING(au.email, 1, 2) || '***@***' || SUBSTRING(au.email FROM POSITION('@' IN au.email) + LENGTH(SUBSTRING(au.email FROM POSITION('@' IN au.email))) - 3)
      ELSE '***@***'
    END as email_masked,
    at.tier_level,
    COALESCE(rs.vip_level, 1) as vip_level,
    up.created_at as joined_at,
    COALESCE(rs.total_volume_all_time, 0) as total_volume,
    COALESCE((
      SELECT SUM(tc.commission_amount)
      FROM tier_commissions tc
      WHERE tc.affiliate_id = p_user_id AND tc.source_user_id = at.referral_id
    ), 0) as commission_earned
  FROM affiliate_tiers at
  JOIN user_profiles up ON up.id = at.referral_id
  LEFT JOIN auth.users au ON au.id = at.referral_id
  LEFT JOIN referral_stats rs ON rs.user_id = at.referral_id
  WHERE at.affiliate_id = p_user_id
  ORDER BY at.tier_level, up.created_at DESC;
END;
$$;

-- Get sub-affiliates (users who have their own referrals)
CREATE OR REPLACE FUNCTION get_sub_affiliates(p_user_id UUID)
RETURNS TABLE(
  affiliate_id UUID,
  username TEXT,
  tier_level INTEGER,
  vip_level INTEGER,
  referral_count INTEGER,
  total_volume NUMERIC,
  override_earned NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    at.referral_id as affiliate_id,
    COALESCE(up.username, 'User') as username,
    at.tier_level,
    COALESCE(rs.vip_level, 1) as vip_level,
    COALESCE(rs.total_referrals, 0) as referral_count,
    COALESCE(rs.total_volume_all_time, 0) as total_volume,
    COALESCE((
      SELECT SUM(tc.commission_amount)
      FROM tier_commissions tc
      WHERE tc.affiliate_id = p_user_id 
        AND tc.tier_level > 1
        AND EXISTS (
          SELECT 1 FROM affiliate_tiers at2 
          WHERE at2.affiliate_id = at.referral_id 
            AND at2.referral_id = tc.source_user_id
        )
    ), 0) as override_earned
  FROM affiliate_tiers at
  JOIN user_profiles up ON up.id = at.referral_id
  LEFT JOIN referral_stats rs ON rs.user_id = at.referral_id
  WHERE at.affiliate_id = p_user_id
    AND at.tier_level <= 4
    AND EXISTS (
      SELECT 1 FROM user_profiles up2 WHERE up2.referred_by = at.referral_id
    )
  ORDER BY at.tier_level, rs.total_referrals DESC NULLS LAST;
END;
$$;

-- Get tier breakdown with statistics
CREATE OR REPLACE FUNCTION get_tier_breakdown(p_user_id UUID)
RETURNS TABLE(
  tier INTEGER,
  referral_count BIGINT,
  total_volume NUMERIC,
  total_earnings NUMERIC,
  override_rate NUMERIC,
  active_traders BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    at.tier_level as tier,
    COUNT(DISTINCT at.referral_id) as referral_count,
    COALESCE(SUM(rs.total_volume_all_time), 0) as total_volume,
    COALESCE(SUM(
      CASE at.tier_level
        WHEN 1 THEN rs2.total_earnings
        WHEN 2 THEN rs2.tier_2_earnings
        WHEN 3 THEN rs2.tier_3_earnings
        WHEN 4 THEN rs2.tier_4_earnings
        WHEN 5 THEN rs2.tier_5_earnings
      END
    ), 0) as total_earnings,
    get_tier_override_rate(at.tier_level) * 100 as override_rate,
    COUNT(DISTINCT CASE WHEN rs.total_volume_30d > 0 THEN at.referral_id END) as active_traders
  FROM affiliate_tiers at
  LEFT JOIN referral_stats rs ON rs.user_id = at.referral_id
  LEFT JOIN referral_stats rs2 ON rs2.user_id = p_user_id
  WHERE at.affiliate_id = p_user_id
  GROUP BY at.tier_level
  ORDER BY at.tier_level;
END;
$$;

-- Update VIP levels table with tier names from document
UPDATE vip_levels SET
  level_name = CASE level_number
    WHEN 1 THEN 'Beginner'
    WHEN 2 THEN 'Intermediate'
    WHEN 3 THEN 'Advanced'
    WHEN 4 THEN 'VIP 1'
    WHEN 5 THEN 'VIP 2'
    WHEN 6 THEN 'Diamond'
  END,
  level_emoji = CASE level_number
    WHEN 1 THEN 'bronze'
    WHEN 2 THEN 'silver'
    WHEN 3 THEN 'gold'
    WHEN 4 THEN 'star'
    WHEN 5 THEN 'crown'
    WHEN 6 THEN 'diamond'
  END,
  commission_rate = CASE level_number
    WHEN 1 THEN 10
    WHEN 2 THEN 20
    WHEN 3 THEN 30
    WHEN 4 THEN 40
    WHEN 5 THEN 50
    WHEN 6 THEN 70
  END,
  rebate_rate = CASE level_number
    WHEN 1 THEN 5
    WHEN 2 THEN 6
    WHEN 3 THEN 7
    WHEN 4 THEN 8
    WHEN 5 THEN 10
    WHEN 6 THEN 15
  END
WHERE level_number BETWEEN 1 AND 6;
