/*
  # Update Hybrid Plan to 40% RevShare

  ## Changes
  - Updates the hybrid plan multiplier from 0.6 (60%) to 0.4 (40%)
  - Hybrid users now get 40% of their normal revshare rate plus full CPA bonuses
*/

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
        v_commission := v_commission * 0.4;
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
