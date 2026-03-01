/*
  # Add Notifications to Affiliate Commission Distribution

  ## Summary
  Updates the distribute_multi_tier_commissions function to send notifications
  to affiliates when they receive commissions from closing fees and other trading fees.

  ## Changes
  1. Adds notification sending for each tier commission
  2. Creates transaction records for each commission
  3. Includes detailed information about the commission source

  ## Notifications Include
  - Commission amount earned
  - Tier level
  - VIP level
  - Source trader information
  - Trade details
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
  v_trader_email TEXT;
BEGIN
  -- Get trader's email for notification
  SELECT email INTO v_trader_email
  FROM auth.users
  WHERE id = p_trader_id;

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

    SELECT COALESCE(acp.plan_type, 'revshare') INTO v_compensation_plan
    FROM affiliate_compensation_plans acp
    WHERE acp.user_id = v_affiliate.affiliate_id;

    IF v_compensation_plan IS NULL OR v_compensation_plan IN ('revshare', 'hybrid', 'auto_optimize') THEN
      v_tier_1_commission := p_fee_amount * get_vip_commission_rate(v_vip_level);
      v_override_rate := get_tier_override_rate(v_affiliate.tier_level);
      v_commission := v_tier_1_commission * v_override_rate;

      IF v_compensation_plan = 'hybrid' THEN
        v_commission := v_commission * 0.6;
      END IF;

      IF v_commission > 0 THEN
        -- Record tier commission
        INSERT INTO tier_commissions (
          affiliate_id, source_user_id, tier_level, trade_id,
          trade_amount, fee_amount, source_commission, override_rate,
          commission_amount, affiliate_vip_level, status
        ) VALUES (
          v_affiliate.affiliate_id, p_trader_id, v_affiliate.tier_level, p_trade_id,
          p_trade_amount, p_fee_amount, v_tier_1_commission, v_override_rate,
          v_commission, v_vip_level, 'pending'
        );

        -- Update wallet balance
        UPDATE wallets
        SET balance = balance + v_commission, updated_at = now()
        WHERE user_id = v_affiliate.affiliate_id AND currency = 'USDT' AND wallet_type = 'main';

        -- Update referral stats
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

        -- Create transaction record
        INSERT INTO transactions (
          user_id,
          transaction_type,
          currency,
          amount,
          status,
          confirmed_at,
          details
        ) VALUES (
          v_affiliate.affiliate_id,
          'affiliate_commission',
          'USDT',
          v_commission,
          'completed',
          now(),
          format('Tier %s affiliate commission from network trading', v_affiliate.tier_level)
        );

        -- Send notification to affiliate
        PERFORM send_notification(
          v_affiliate.affiliate_id,
          'affiliate_payout',
          format('Tier %s Commission: +%s USDT', v_affiliate.tier_level, ROUND(v_commission, 2)),
          format('You earned %s USDT from tier %s of your affiliate network. VIP Level: %s (Override: %s%%)', 
            ROUND(v_commission, 2),
            v_affiliate.tier_level,
            v_vip_level,
            ROUND(v_override_rate * 100, 0)
          ),
          jsonb_build_object(
            'commission_amount', v_commission,
            'currency', 'USDT',
            'tier_level', v_affiliate.tier_level,
            'vip_level', v_vip_level,
            'override_rate', v_override_rate * 100,
            'base_commission', v_tier_1_commission,
            'source_user_id', p_trader_id,
            'source_trader_email', COALESCE(SUBSTRING(v_trader_email FROM 1 FOR 3) || '***', 'User'),
            'trade_amount', p_trade_amount,
            'fee_amount', p_fee_amount,
            'compensation_plan', v_compensation_plan
          )
        );

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
GRANT EXECUTE ON FUNCTION distribute_multi_tier_commissions TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_multi_tier_commissions TO service_role;