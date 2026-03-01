/*
  # Implement Hybrid and Auto-Optimize Plans

  ## Overview
  Completes the implementation of all 4 compensation plans:
  - Revenue Share: 100% revshare based on VIP level
  - CPA Only: Only CPA bonuses, no revshare
  - Hybrid: 60% revshare + full CPA bonuses
  - Auto-Optimize: System automatically picks best plan

  ## Changes
  1. Add tracking columns for auto-optimize analysis
  2. Create function to analyze and suggest best plan
  3. Update commission distribution for CPA-only plan
  4. Add plan performance tracking

  ## Auto-Optimize Logic
  Analyzes referral behavior and recommends plan based on:
  - Number of referrals who complete milestones (favors CPA)
  - Volume of referral trading activity (favors RevShare)
  - Calculates projected earnings for each plan
*/

-- Add columns for plan performance tracking
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'affiliate_compensation_plans' AND column_name = 'revshare_earnings_30d'
  ) THEN
    ALTER TABLE affiliate_compensation_plans 
      ADD COLUMN revshare_earnings_30d NUMERIC DEFAULT 0,
      ADD COLUMN cpa_earnings_30d NUMERIC DEFAULT 0,
      ADD COLUMN last_optimization_check TIMESTAMPTZ,
      ADD COLUMN recommended_plan TEXT;
  END IF;
END $$;

-- Function to analyze and get best plan recommendation
CREATE OR REPLACE FUNCTION analyze_best_plan(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_revshare_30d NUMERIC;
  v_cpa_30d NUMERIC;
  v_projected_revshare NUMERIC;
  v_projected_cpa NUMERIC;
  v_projected_hybrid NUMERIC;
  v_referral_count INTEGER;
  v_active_traders INTEGER;
  v_avg_volume NUMERIC;
  v_best_plan TEXT;
  v_vip_level INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_referral_count
  FROM user_profiles
  WHERE referred_by = p_user_id;

  SELECT 
    COUNT(DISTINCT up.id),
    COALESCE(AVG(rs.total_volume_30d), 0)
  INTO v_active_traders, v_avg_volume
  FROM user_profiles up
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  WHERE up.referred_by = p_user_id
    AND rs.total_volume_30d > 0;

  SELECT COALESCE(SUM(commission_amount), 0) INTO v_revshare_30d
  FROM tier_commissions
  WHERE affiliate_id = p_user_id
    AND created_at > now() - INTERVAL '30 days';

  SELECT COALESCE(SUM(
    CASE 
      WHEN kyc_paid THEN 10 ELSE 0 
    END +
    CASE 
      WHEN deposit_paid THEN 25 ELSE 0 
    END +
    CASE 
      WHEN trade_paid THEN 50 ELSE 0 
    END +
    CASE 
      WHEN volume_paid THEN 100 ELSE 0 
    END
  ), 0) INTO v_cpa_30d
  FROM cpa_payouts
  WHERE affiliate_id = p_user_id
    AND created_at > now() - INTERVAL '30 days';

  SELECT COALESCE(vip_level, 1) INTO v_vip_level
  FROM referral_stats
  WHERE user_id = p_user_id;

  v_projected_revshare := v_revshare_30d;
  v_projected_cpa := v_referral_count * 45;
  v_projected_hybrid := (v_revshare_30d * 0.6) + v_projected_cpa;

  IF v_projected_cpa > v_projected_revshare AND v_projected_cpa > v_projected_hybrid THEN
    v_best_plan := 'cpa';
  ELSIF v_projected_hybrid > v_projected_revshare THEN
    v_best_plan := 'hybrid';
  ELSE
    v_best_plan := 'revshare';
  END IF;

  IF v_active_traders > v_referral_count * 0.3 AND v_avg_volume > 5000 THEN
    v_best_plan := 'revshare';
  ELSIF v_referral_count > 10 AND v_active_traders < v_referral_count * 0.1 THEN
    v_best_plan := 'cpa';
  END IF;

  UPDATE affiliate_compensation_plans
  SET 
    revshare_earnings_30d = v_revshare_30d,
    cpa_earnings_30d = v_cpa_30d,
    last_optimization_check = now(),
    recommended_plan = v_best_plan
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'referral_count', v_referral_count,
    'active_traders', v_active_traders,
    'avg_volume', v_avg_volume,
    'revshare_30d', v_revshare_30d,
    'cpa_30d', v_cpa_30d,
    'projected_revshare', v_projected_revshare,
    'projected_cpa', v_projected_cpa,
    'projected_hybrid', v_projected_hybrid,
    'recommended_plan', v_best_plan,
    'vip_level', v_vip_level
  );
END;
$$;

-- Function for auto-optimize to apply recommended plan
CREATE OR REPLACE FUNCTION apply_auto_optimize(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_analysis JSONB;
  v_recommended TEXT;
  v_current_plan TEXT;
BEGIN
  SELECT plan_type INTO v_current_plan
  FROM affiliate_compensation_plans
  WHERE user_id = p_user_id;

  IF v_current_plan != 'auto_optimize' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is not on auto-optimize plan'
    );
  END IF;

  v_analysis := analyze_best_plan(p_user_id);
  v_recommended := v_analysis->>'recommended_plan';

  UPDATE affiliate_compensation_plans
  SET 
    effective_plan = v_recommended,
    updated_at = now()
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'analysis', v_analysis,
    'applied_plan', v_recommended
  );
END;
$$;

-- Add effective_plan column for auto-optimize
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'affiliate_compensation_plans' AND column_name = 'effective_plan'
  ) THEN
    ALTER TABLE affiliate_compensation_plans 
      ADD COLUMN effective_plan TEXT DEFAULT 'revshare';
  END IF;
END $$;

-- Update distribute_multi_tier_commissions to handle CPA-only plan
CREATE OR REPLACE FUNCTION distribute_multi_tier_commissions(
  p_trader_id UUID,
  p_trade_amount NUMERIC,
  p_fee_amount NUMERIC,
  p_trade_id UUID DEFAULT NULL
)
RETURNS TABLE(
  affiliate_id UUID,
  tier_level INTEGER,
  commission_amount NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_affiliate RECORD;
  v_tier_1_commission NUMERIC;
  v_override_rate NUMERIC;
  v_commission NUMERIC;
  v_vip_level INTEGER;
  v_compensation_plan TEXT;
  v_effective_plan TEXT;
BEGIN
  FOR v_affiliate IN (
    SELECT at.affiliate_id, at.tier_level
    FROM affiliate_tiers at
    WHERE at.referral_id = p_trader_id
    ORDER BY at.tier_level
  ) LOOP
    SELECT COALESCE(rs.vip_level, 1) INTO v_vip_level
    FROM referral_stats rs
    WHERE rs.user_id = v_affiliate.affiliate_id;

    IF v_vip_level IS NULL THEN
      v_vip_level := 1;
    END IF;

    SELECT COALESCE(acp.plan_type, 'revshare'), COALESCE(acp.effective_plan, acp.plan_type, 'revshare')
    INTO v_compensation_plan, v_effective_plan
    FROM affiliate_compensation_plans acp
    WHERE acp.user_id = v_affiliate.affiliate_id;

    IF v_compensation_plan = 'auto_optimize' THEN
      v_compensation_plan := COALESCE(v_effective_plan, 'revshare');
    END IF;

    IF v_compensation_plan = 'cpa' THEN
      CONTINUE;
    END IF;

    IF v_compensation_plan IS NULL OR v_compensation_plan IN ('revshare', 'hybrid', 'auto_optimize') THEN
      v_tier_1_commission := p_fee_amount * get_vip_commission_rate(v_vip_level);
      v_override_rate := get_tier_override_rate(v_affiliate.tier_level);
      v_commission := v_tier_1_commission * v_override_rate;

      IF v_compensation_plan = 'hybrid' THEN
        v_commission := v_commission * 0.6;
      END IF;

      IF v_commission > 0 THEN
        INSERT INTO tier_commissions (
          affiliate_id, source_user_id, tier_level, trade_id,
          trade_amount, fee_amount, source_commission, override_rate,
          commission_amount, affiliate_vip_level, status
        ) VALUES (
          v_affiliate.affiliate_id, p_trader_id, v_affiliate.tier_level, p_trade_id,
          p_trade_amount, p_fee_amount, v_tier_1_commission, v_override_rate,
          v_commission, v_vip_level, 'pending'
        );

        UPDATE wallets
        SET balance = balance + v_commission, updated_at = now()
        WHERE user_id = v_affiliate.affiliate_id AND currency = 'USDT' AND wallet_type = 'main';

        UPDATE referral_stats
        SET 
          total_earnings = CASE WHEN v_affiliate.tier_level = 1 THEN COALESCE(total_earnings, 0) + v_commission ELSE total_earnings END,
          tier_2_earnings = CASE WHEN v_affiliate.tier_level = 2 THEN COALESCE(tier_2_earnings, 0) + v_commission ELSE tier_2_earnings END,
          tier_3_earnings = CASE WHEN v_affiliate.tier_level = 3 THEN COALESCE(tier_3_earnings, 0) + v_commission ELSE tier_3_earnings END,
          tier_4_earnings = CASE WHEN v_affiliate.tier_level = 4 THEN COALESCE(tier_4_earnings, 0) + v_commission ELSE tier_4_earnings END,
          tier_5_earnings = CASE WHEN v_affiliate.tier_level = 5 THEN COALESCE(tier_5_earnings, 0) + v_commission ELSE tier_5_earnings END,
          lifetime_earnings = COALESCE(lifetime_earnings, 0) + v_commission,
          this_month_earnings = COALESCE(this_month_earnings, 0) + v_commission,
          updated_at = now()
        WHERE user_id = v_affiliate.affiliate_id;

        affiliate_id := v_affiliate.affiliate_id;
        tier_level := v_affiliate.tier_level;
        commission_amount := v_commission;
        RETURN NEXT;
      END IF;
    END IF;
  END LOOP;

  RETURN;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION analyze_best_plan(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION apply_auto_optimize(UUID) TO authenticated;
