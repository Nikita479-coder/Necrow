/*
  # Affiliate Commission Functions

  ## Functions Created
  1. `build_affiliate_chain` - Creates the 5-tier referral chain when a user signs up
  2. `calculate_tier_override_rate` - Returns the override rate for each tier
  3. `get_vip_commission_rate` - Returns commission rate based on VIP level
  4. `distribute_multi_tier_commissions` - Distributes commissions across all tiers
  5. `get_affiliate_stats` - Returns comprehensive affiliate statistics
  6. `set_compensation_plan` - Allows users to select their compensation plan

  ## Security
  All functions use SECURITY DEFINER with restricted search_path
*/

-- Get VIP commission rate
CREATE OR REPLACE FUNCTION get_vip_commission_rate(p_vip_level INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN CASE p_vip_level
    WHEN 1 THEN 0.10  -- 10% Beginner
    WHEN 2 THEN 0.20  -- 20% Intermediate
    WHEN 3 THEN 0.30  -- 30% Advanced
    WHEN 4 THEN 0.40  -- 40% VIP 1
    WHEN 5 THEN 0.50  -- 50% VIP 2
    WHEN 6 THEN 0.70  -- 70% Diamond
    ELSE 0.10
  END;
END;
$$;

-- Get tier override rate
CREATE OR REPLACE FUNCTION get_tier_override_rate(p_tier_level INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN CASE p_tier_level
    WHEN 1 THEN 1.00  -- 100% (full commission)
    WHEN 2 THEN 0.20  -- 20% of tier-1 commission
    WHEN 3 THEN 0.10  -- 10% of tier-1 commission
    WHEN 4 THEN 0.05  -- 5% of tier-1 commission
    WHEN 5 THEN 0.02  -- 2% of tier-1 commission
    ELSE 0.00
  END;
END;
$$;

-- Build affiliate chain when a new user signs up
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
BEGIN
  IF NEW.referred_by IS NULL THEN
    RETURN NEW;
  END IF;

  v_current_referrer_id := NEW.referred_by;
  v_direct_referrer_id := NEW.referred_by;

  WHILE v_current_referrer_id IS NOT NULL AND v_tier <= 5 LOOP
    INSERT INTO affiliate_tiers (affiliate_id, referral_id, tier_level, direct_referrer_id)
    VALUES (v_current_referrer_id, NEW.id, v_tier, v_direct_referrer_id)
    ON CONFLICT (affiliate_id, referral_id) DO NOTHING;

    IF v_tier > 1 THEN
      UPDATE referral_stats
      SET 
        tier_2_referrals = CASE WHEN v_tier = 2 THEN COALESCE(tier_2_referrals, 0) + 1 ELSE tier_2_referrals END,
        tier_3_referrals = CASE WHEN v_tier = 3 THEN COALESCE(tier_3_referrals, 0) + 1 ELSE tier_3_referrals END,
        tier_4_referrals = CASE WHEN v_tier = 4 THEN COALESCE(tier_4_referrals, 0) + 1 ELSE tier_4_referrals END,
        tier_5_referrals = CASE WHEN v_tier = 5 THEN COALESCE(tier_5_referrals, 0) + 1 ELSE tier_5_referrals END,
        updated_at = now()
      WHERE user_id = v_current_referrer_id;
    END IF;

    SELECT referred_by INTO v_current_referrer_id
    FROM user_profiles
    WHERE id = v_current_referrer_id;

    v_tier := v_tier + 1;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_build_affiliate_chain ON user_profiles;
CREATE TRIGGER trigger_build_affiliate_chain
  AFTER INSERT OR UPDATE OF referred_by ON user_profiles
  FOR EACH ROW
  WHEN (NEW.referred_by IS NOT NULL)
  EXECUTE FUNCTION build_affiliate_chain();

-- Distribute multi-tier commissions
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

-- Get comprehensive affiliate stats
CREATE OR REPLACE FUNCTION get_affiliate_stats(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_tier_stats JSONB;
  v_recent_commissions JSONB;
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

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', tc.id,
      'tier_level', tc.tier_level,
      'commission_amount', tc.commission_amount,
      'trade_amount', tc.trade_amount,
      'created_at', tc.created_at
    ) ORDER BY tc.created_at DESC
  ), '[]'::jsonb) INTO v_recent_commissions
  FROM (
    SELECT * FROM tier_commissions 
    WHERE affiliate_id = p_user_id 
    ORDER BY created_at DESC 
    LIMIT 20
  ) tc;

  SELECT jsonb_build_object(
    'user_id', p_user_id,
    'vip_level', COALESCE(rs.vip_level, 1),
    'compensation_plan', COALESCE(acp.plan_type, 'revshare'),
    'total_network_size', COALESCE(rs.total_referrals, 0) + COALESCE(rs.tier_2_referrals, 0) + COALESCE(rs.tier_3_referrals, 0) + COALESCE(rs.tier_4_referrals, 0) + COALESCE(rs.tier_5_referrals, 0),
    'tier_stats', COALESCE(v_tier_stats, '{}'::jsonb),
    'lifetime_earnings', COALESCE(rs.lifetime_earnings, 0),
    'cpa_earnings', COALESCE(rs.cpa_earnings, 0),
    'this_month_earnings', COALESCE(rs.this_month_earnings, 0),
    'pending_payout', COALESCE(rs.pending_payout, 0),
    'volume_30d', COALESCE(rs.total_volume_30d, 0),
    'recent_commissions', v_recent_commissions,
    'commission_rate', get_vip_commission_rate(COALESCE(rs.vip_level, 1)) * 100
  ) INTO v_result
  FROM referral_stats rs
  LEFT JOIN affiliate_compensation_plans acp ON acp.user_id = rs.user_id
  WHERE rs.user_id = p_user_id;

  IF v_result IS NULL THEN
    v_result := jsonb_build_object(
      'user_id', p_user_id,
      'vip_level', 1,
      'compensation_plan', 'revshare',
      'total_network_size', 0,
      'tier_stats', jsonb_build_object(
        'tier_1', jsonb_build_object('count', 0, 'earnings', 0),
        'tier_2', jsonb_build_object('count', 0, 'earnings', 0),
        'tier_3', jsonb_build_object('count', 0, 'earnings', 0),
        'tier_4', jsonb_build_object('count', 0, 'earnings', 0),
        'tier_5', jsonb_build_object('count', 0, 'earnings', 0)
      ),
      'lifetime_earnings', 0,
      'cpa_earnings', 0,
      'this_month_earnings', 0,
      'pending_payout', 0,
      'volume_30d', 0,
      'recent_commissions', '[]'::jsonb,
      'commission_rate', 10
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Set compensation plan
CREATE OR REPLACE FUNCTION set_compensation_plan(
  p_user_id UUID,
  p_plan_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_plan_type NOT IN ('revshare', 'cpa', 'hybrid', 'auto_optimize') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid plan type');
  END IF;

  INSERT INTO affiliate_compensation_plans (user_id, plan_type, is_auto_optimized, updated_at)
  VALUES (p_user_id, p_plan_type, p_plan_type = 'auto_optimize', now())
  ON CONFLICT (user_id) DO UPDATE SET
    plan_type = p_plan_type,
    is_auto_optimized = p_plan_type = 'auto_optimize',
    updated_at = now();

  RETURN jsonb_build_object('success', true, 'plan_type', p_plan_type);
END;
$$;

-- Calculate estimated earnings
CREATE OR REPLACE FUNCTION calculate_affiliate_earnings(
  p_vip_level INTEGER,
  p_trade_volume NUMERIC,
  p_fee_rate NUMERIC DEFAULT 0.001
)
RETURNS TABLE(
  tier INTEGER,
  override_rate NUMERIC,
  earnings NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fee_amount NUMERIC;
  v_tier_1_commission NUMERIC;
BEGIN
  v_fee_amount := p_trade_volume * p_fee_rate;
  v_tier_1_commission := v_fee_amount * get_vip_commission_rate(p_vip_level);

  FOR tier IN 1..5 LOOP
    override_rate := get_tier_override_rate(tier) * 100;
    earnings := v_tier_1_commission * get_tier_override_rate(tier);
    RETURN NEXT;
  END LOOP;

  RETURN;
END;
$$;
