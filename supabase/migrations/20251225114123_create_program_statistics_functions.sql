/*
  # Create Program Statistics Functions

  ## Overview
  Creates functions to get comprehensive program statistics for the frontend,
  including both referral and affiliate program data.

  ## Functions
  1. `get_program_overview` - Returns overview of both programs
  2. `get_referral_program_stats` - Stats for simple referral program
  3. `get_affiliate_program_stats` - Stats for affiliate program
  4. `get_cpa_progress` - CPA milestone progress for referrals

  ## Security
  All functions use SECURITY DEFINER
*/

-- Get comprehensive program overview
CREATE OR REPLACE FUNCTION get_program_overview(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_active_program TEXT;
  v_referral_code TEXT;
  v_total_referrals INTEGER;
  v_total_earnings NUMERIC;
  v_this_month_earnings NUMERIC;
  v_vip_level INTEGER;
  v_compensation_plan TEXT;
BEGIN
  SELECT 
    COALESCE(up.active_program, 'referral'),
    up.referral_code
  INTO v_active_program, v_referral_code
  FROM user_profiles up
  WHERE up.id = p_user_id;

  SELECT 
    COALESCE(rs.total_referrals, 0),
    COALESCE(rs.lifetime_earnings, 0),
    COALESCE(rs.this_month_earnings, 0),
    COALESCE(rs.vip_level, 1)
  INTO v_total_referrals, v_total_earnings, v_this_month_earnings, v_vip_level
  FROM referral_stats rs
  WHERE rs.user_id = p_user_id;

  SELECT COALESCE(plan_type, 'revshare') INTO v_compensation_plan
  FROM affiliate_compensation_plans
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'active_program', COALESCE(v_active_program, 'referral'),
    'referral_code', v_referral_code,
    'total_referrals', COALESCE(v_total_referrals, 0),
    'total_earnings', COALESCE(v_total_earnings, 0),
    'this_month_earnings', COALESCE(v_this_month_earnings, 0),
    'vip_level', COALESCE(v_vip_level, 1),
    'compensation_plan', COALESCE(v_compensation_plan, 'revshare')
  );
END;
$$;

-- Get simple referral program stats
CREATE OR REPLACE FUNCTION get_referral_program_stats(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_referrals JSONB;
  v_recent_commissions JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', up.id,
      'username', COALESCE(up.username, 'User'),
      'joined_at', up.created_at,
      'total_volume', COALESCE(rs.total_volume_all_time, 0),
      'your_earnings', COALESCE((
        SELECT SUM(commission_amount) 
        FROM referral_commissions 
        WHERE referrer_id = p_user_id AND referee_id = up.id
      ), 0)
    ) ORDER BY up.created_at DESC
  ), '[]'::jsonb) INTO v_referrals
  FROM user_profiles up
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  WHERE up.referred_by = p_user_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', rc.id,
      'amount', rc.commission_amount,
      'trade_amount', rc.trade_amount,
      'fee_amount', rc.fee_amount,
      'commission_rate', rc.commission_rate,
      'created_at', rc.created_at
    ) ORDER BY rc.created_at DESC
  ), '[]'::jsonb) INTO v_recent_commissions
  FROM (
    SELECT * FROM referral_commissions
    WHERE referrer_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 20
  ) rc;

  SELECT jsonb_build_object(
    'total_referrals', COALESCE(rs.total_referrals, 0),
    'total_earnings', COALESCE(rs.total_earnings, 0),
    'this_month_earnings', COALESCE(rs.this_month_earnings, 0),
    'total_volume_30d', COALESCE(rs.total_volume_30d, 0),
    'vip_level', COALESCE(rs.vip_level, 1),
    'commission_rate', get_commission_rate(COALESCE(rs.vip_level, 1)),
    'rebate_rate', get_rebate_rate(COALESCE(rs.vip_level, 1)),
    'referrals', v_referrals,
    'recent_commissions', v_recent_commissions
  ) INTO v_result
  FROM referral_stats rs
  WHERE rs.user_id = p_user_id;

  IF v_result IS NULL THEN
    v_result := jsonb_build_object(
      'total_referrals', 0,
      'total_earnings', 0,
      'this_month_earnings', 0,
      'total_volume_30d', 0,
      'vip_level', 1,
      'commission_rate', 10,
      'rebate_rate', 5,
      'referrals', '[]'::jsonb,
      'recent_commissions', '[]'::jsonb
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Get affiliate program stats (already exists as get_affiliate_stats, but enhanced)
CREATE OR REPLACE FUNCTION get_affiliate_program_stats(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_tier_stats JSONB;
  v_network JSONB;
  v_cpa_stats JSONB;
  v_plan_analysis JSONB;
BEGIN
  SELECT jsonb_build_object(
    'tier_1', jsonb_build_object('count', COALESCE(rs.total_referrals, 0), 'earnings', COALESCE(rs.total_earnings, 0)),
    'tier_2', jsonb_build_object('count', COALESCE(rs.tier_2_referrals, 0), 'earnings', COALESCE(rs.tier_2_earnings, 0)),
    'tier_3', jsonb_build_object('count', COALESCE(rs.tier_3_referrals, 0), 'earnings', COALESCE(rs.tier_3_earnings, 0)),
    'tier_4', jsonb_build_object('count', COALESCE(rs.tier_4_referrals, 0), 'earnings', COALESCE(rs.tier_4_earnings, 0)),
    'tier_5', jsonb_build_object('count', COALESCE(rs.tier_5_referrals, 0), 'earnings', COALESCE(rs.tier_5_earnings, 0))
  ) INTO v_tier_stats
  FROM referral_stats rs
  WHERE rs.user_id = p_user_id;

  SELECT COALESCE(jsonb_agg(row_to_json(n)), '[]'::jsonb) INTO v_network
  FROM (
    SELECT * FROM get_affiliate_network(p_user_id) LIMIT 50
  ) n;

  SELECT jsonb_build_object(
    'total_cpa_earned', COALESCE(SUM(total_cpa_earned), 0),
    'kyc_completions', COUNT(*) FILTER (WHERE kyc_paid),
    'first_deposits', COUNT(*) FILTER (WHERE deposit_paid),
    'first_trades', COUNT(*) FILTER (WHERE trade_paid),
    'volume_thresholds', COUNT(*) FILTER (WHERE volume_paid)
  ) INTO v_cpa_stats
  FROM cpa_payouts
  WHERE affiliate_id = p_user_id;

  v_plan_analysis := analyze_best_plan(p_user_id);

  SELECT jsonb_build_object(
    'vip_level', COALESCE(rs.vip_level, 1),
    'vip_name', CASE COALESCE(rs.vip_level, 1)
      WHEN 1 THEN 'Beginner'
      WHEN 2 THEN 'Intermediate'
      WHEN 3 THEN 'Advanced'
      WHEN 4 THEN 'VIP 1'
      WHEN 5 THEN 'VIP 2'
      WHEN 6 THEN 'Diamond'
    END,
    'compensation_plan', COALESCE(acp.plan_type, 'revshare'),
    'effective_plan', COALESCE(acp.effective_plan, acp.plan_type, 'revshare'),
    'commission_rate', get_vip_commission_rate(COALESCE(rs.vip_level, 1)) * 100,
    'lifetime_earnings', COALESCE(rs.lifetime_earnings, 0),
    'this_month_earnings', COALESCE(rs.this_month_earnings, 0),
    'cpa_earnings', COALESCE(rs.cpa_earnings, 0),
    'total_volume_30d', COALESCE(rs.total_volume_30d, 0),
    'total_network_size', COALESCE(rs.total_referrals, 0) + 
                          COALESCE(rs.tier_2_referrals, 0) + 
                          COALESCE(rs.tier_3_referrals, 0) + 
                          COALESCE(rs.tier_4_referrals, 0) + 
                          COALESCE(rs.tier_5_referrals, 0),
    'tier_stats', COALESCE(v_tier_stats, '{}'::jsonb),
    'network', v_network,
    'cpa_stats', COALESCE(v_cpa_stats, '{}'::jsonb),
    'plan_analysis', v_plan_analysis,
    'tier_rates', jsonb_build_object(
      'tier_1', 100,
      'tier_2', 20,
      'tier_3', 10,
      'tier_4', 5,
      'tier_5', 2
    )
  ) INTO v_result
  FROM referral_stats rs
  LEFT JOIN affiliate_compensation_plans acp ON acp.user_id = rs.user_id
  WHERE rs.user_id = p_user_id;

  IF v_result IS NULL THEN
    v_result := jsonb_build_object(
      'vip_level', 1,
      'vip_name', 'Beginner',
      'compensation_plan', 'revshare',
      'effective_plan', 'revshare',
      'commission_rate', 10,
      'lifetime_earnings', 0,
      'this_month_earnings', 0,
      'cpa_earnings', 0,
      'total_volume_30d', 0,
      'total_network_size', 0,
      'tier_stats', jsonb_build_object(
        'tier_1', jsonb_build_object('count', 0, 'earnings', 0),
        'tier_2', jsonb_build_object('count', 0, 'earnings', 0),
        'tier_3', jsonb_build_object('count', 0, 'earnings', 0),
        'tier_4', jsonb_build_object('count', 0, 'earnings', 0),
        'tier_5', jsonb_build_object('count', 0, 'earnings', 0)
      ),
      'network', '[]'::jsonb,
      'cpa_stats', jsonb_build_object(
        'total_cpa_earned', 0,
        'kyc_completions', 0,
        'first_deposits', 0,
        'first_trades', 0,
        'volume_thresholds', 0
      ),
      'plan_analysis', '{}'::jsonb,
      'tier_rates', jsonb_build_object(
        'tier_1', 100,
        'tier_2', 20,
        'tier_3', 10,
        'tier_4', 5,
        'tier_5', 2
      )
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Get CPA progress for a referrer's referrals
CREATE OR REPLACE FUNCTION get_cpa_progress(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'referred_user_id', cp.referred_user_id,
        'username', COALESCE(up.username, 'User'),
        'joined_at', up.created_at,
        'kyc_completed', COALESCE(cp.kyc_paid, false),
        'first_deposit', COALESCE(cp.deposit_paid, false),
        'first_trade', COALESCE(cp.trade_paid, false),
        'volume_threshold', COALESCE(cp.volume_paid, false),
        'total_earned', COALESCE(cp.total_cpa_earned, 0),
        'potential_remaining', 
          (CASE WHEN NOT COALESCE(cp.kyc_paid, false) THEN 10 ELSE 0 END) +
          (CASE WHEN NOT COALESCE(cp.deposit_paid, false) THEN 25 ELSE 0 END) +
          (CASE WHEN NOT COALESCE(cp.trade_paid, false) THEN 50 ELSE 0 END) +
          (CASE WHEN NOT COALESCE(cp.volume_paid, false) THEN 100 ELSE 0 END)
      ) ORDER BY up.created_at DESC
    ), '[]'::jsonb)
    FROM user_profiles up
    LEFT JOIN cpa_payouts cp ON cp.referred_user_id = up.id AND cp.affiliate_id = p_user_id
    WHERE up.referred_by = p_user_id
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_program_overview(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_program_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_affiliate_program_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_cpa_progress(UUID) TO authenticated;
