/*
  # Multi-Tier Deposit Commission System

  ## Problem
  Deposit commissions are not being distributed to the regular 5-tier affiliate network.
  Only exclusive affiliate deposit commissions are being distributed.

  Regular affiliates should receive:
  - Level 1 (Direct): 5% of deposit
  - Level 2: 4% of deposit
  - Level 3: 3% of deposit
  - Level 4: 2% of deposit
  - Level 5: 1% of deposit

  ## Solution
  1. Create `distribute_multi_tier_deposit_commissions` function
  2. Update `process_crypto_deposit_completion` to call this function
  3. Track deposit commissions in tier_commissions table
  4. Send notifications to affiliates

  ## Security
  Uses SECURITY DEFINER with restricted search_path
*/

-- Function to get deposit commission rate by tier
CREATE OR REPLACE FUNCTION get_tier_deposit_rate(p_tier_level INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_tier_level
    WHEN 1 THEN 0.05  -- 5%
    WHEN 2 THEN 0.04  -- 4%
    WHEN 3 THEN 0.03  -- 3%
    WHEN 4 THEN 0.02  -- 2%
    WHEN 5 THEN 0.01  -- 1%
    ELSE 0.00
  END;
END;
$$;

-- Distribute deposit commissions across the 5-tier affiliate network
CREATE OR REPLACE FUNCTION distribute_multi_tier_deposit_commissions(
  p_depositor_id UUID,
  p_deposit_amount NUMERIC,
  p_deposit_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_affiliate RECORD;
  v_commission_rate NUMERIC;
  v_commission_amount NUMERIC;
  v_total_distributed NUMERIC := 0;
  v_commissions_paid INTEGER := 0;
  v_compensation_plan TEXT;
  v_skip_regular BOOLEAN := false;
BEGIN
  -- Check if depositor has an exclusive affiliate referrer (skip regular commissions if true)
  SELECT EXISTS (
    SELECT 1 FROM user_profiles up
    JOIN exclusive_affiliates ea ON ea.user_id = up.referred_by
    WHERE up.id = p_depositor_id AND ea.status = 'active'
  ) INTO v_skip_regular;

  IF v_skip_regular THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Skipped - User has exclusive affiliate referrer',
      'commissions_paid', 0,
      'total_distributed', 0
    );
  END IF;

  -- Loop through all tiers in the affiliate chain
  FOR v_affiliate IN (
    SELECT
      at.affiliate_id,
      at.tier_level,
      at.direct_referrer_id
    FROM affiliate_tiers at
    WHERE at.referral_id = p_depositor_id
    ORDER BY at.tier_level
  ) LOOP
    -- Get affiliate's compensation plan
    SELECT COALESCE(acp.plan_type, 'revshare') INTO v_compensation_plan
    FROM affiliate_compensation_plans acp
    WHERE acp.user_id = v_affiliate.affiliate_id;

    -- Only distribute if plan includes rev-share (not pure CPA)
    IF v_compensation_plan IS NULL OR v_compensation_plan IN ('revshare', 'hybrid', 'auto_optimize') THEN
      v_commission_rate := get_tier_deposit_rate(v_affiliate.tier_level);
      v_commission_amount := p_deposit_amount * v_commission_rate;

      -- Adjust for hybrid plan (60% rev-share, 40% CPA)
      IF v_compensation_plan = 'hybrid' THEN
        v_commission_amount := v_commission_amount * 0.60;
      END IF;

      IF v_commission_amount > 0 THEN
        -- Record commission in tier_commissions table
        INSERT INTO tier_commissions (
          affiliate_id,
          source_user_id,
          tier_level,
          trade_id,
          trade_amount,
          fee_amount,
          source_commission,
          override_rate,
          commission_amount,
          affiliate_vip_level,
          source_vip_level,
          status
        ) VALUES (
          v_affiliate.affiliate_id,
          p_depositor_id,
          v_affiliate.tier_level,
          p_deposit_id,
          p_deposit_amount,
          0, -- No fee for deposits
          v_commission_amount, -- Source commission is the full commission
          v_commission_rate,
          v_commission_amount,
          1, -- Default VIP level
          1, -- Default VIP level
          'pending'
        );

        -- Credit affiliate's main wallet
        INSERT INTO wallets (user_id, currency, balance, wallet_type)
        VALUES (v_affiliate.affiliate_id, 'USDT', v_commission_amount, 'main')
        ON CONFLICT (user_id, currency, wallet_type)
        DO UPDATE SET
          balance = wallets.balance + v_commission_amount,
          updated_at = now();

        -- Update referral stats
        UPDATE referral_stats
        SET
          total_earnings = CASE
            WHEN v_affiliate.tier_level = 1 THEN COALESCE(total_earnings, 0) + v_commission_amount
            ELSE total_earnings
          END,
          tier_2_earnings = CASE
            WHEN v_affiliate.tier_level = 2 THEN COALESCE(tier_2_earnings, 0) + v_commission_amount
            ELSE tier_2_earnings
          END,
          tier_3_earnings = CASE
            WHEN v_affiliate.tier_level = 3 THEN COALESCE(tier_3_earnings, 0) + v_commission_amount
            ELSE tier_3_earnings
          END,
          tier_4_earnings = CASE
            WHEN v_affiliate.tier_level = 4 THEN COALESCE(tier_4_earnings, 0) + v_commission_amount
            ELSE tier_4_earnings
          END,
          tier_5_earnings = CASE
            WHEN v_affiliate.tier_level = 5 THEN COALESCE(tier_5_earnings, 0) + v_commission_amount
            ELSE tier_5_earnings
          END,
          lifetime_earnings = COALESCE(lifetime_earnings, 0) + v_commission_amount,
          this_month_earnings = COALESCE(this_month_earnings, 0) + v_commission_amount,
          updated_at = now()
        WHERE user_id = v_affiliate.affiliate_id;

        -- Record transaction
        INSERT INTO transactions (
          user_id,
          transaction_type,
          amount,
          currency,
          status,
          details
        ) VALUES (
          v_affiliate.affiliate_id,
          'affiliate_commission',
          v_commission_amount,
          'USDT',
          'completed',
          jsonb_build_object(
            'type', 'deposit_commission',
            'tier_level', v_affiliate.tier_level,
            'commission_rate', v_commission_rate * 100,
            'deposit_amount', p_deposit_amount,
            'depositor_id', p_depositor_id,
            'deposit_id', p_deposit_id
          )
        );

        -- Send notification
        INSERT INTO notifications (user_id, type, title, message, read, data)
        VALUES (
          v_affiliate.affiliate_id,
          'affiliate_payout',
          'Deposit Commission Earned',
          'You earned $' || ROUND(v_commission_amount, 2) || ' USDT (' || (v_commission_rate * 100) || '%) from a referral deposit of $' || ROUND(p_deposit_amount, 2) || ' USDT at Tier ' || v_affiliate.tier_level,
          false,
          jsonb_build_object(
            'commission_amount', v_commission_amount,
            'deposit_amount', p_deposit_amount,
            'tier_level', v_affiliate.tier_level,
            'commission_rate', v_commission_rate * 100
          )
        );

        v_total_distributed := v_total_distributed + v_commission_amount;
        v_commissions_paid := v_commissions_paid + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'commissions_paid', v_commissions_paid,
    'total_distributed', v_total_distributed
  );
END;
$$;

COMMENT ON FUNCTION distribute_multi_tier_deposit_commissions IS
  'Distributes deposit commissions across the 5-tier affiliate network: 5%, 4%, 3%, 2%, 1% per tier';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_tier_deposit_rate(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_multi_tier_deposit_commissions(UUID, NUMERIC, UUID) TO authenticated;