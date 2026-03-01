/*
  # Fix Referral Fee Commission Calculation

  ## Description
  Fixes the referral commission calculation. The commission should be based on
  the actual trading fee (which is calculated from margin), while the volume
  for VIP progression should include the leverage multiplier.

  ## Changes
  - Commission calculated from actual fee amount (not leveraged)
  - Volume for VIP level = margin × leverage
  - This properly reflects that fees are only on margin, not notional value

  ## Example
  - User trades with $500 margin at 20x leverage
  - Fee calculated on $500 (not $10,000)
  - Volume counted as $10,000 for VIP progression
  - Commission is percentage of the actual fee paid
*/

CREATE OR REPLACE FUNCTION distribute_trading_fees(
  p_user_id uuid,
  p_transaction_id uuid,
  p_trade_amount numeric,
  p_fee_amount numeric,
  p_leverage integer DEFAULT 1
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id uuid;
  v_referee_signup_date timestamptz;
  v_referrer_stats record;
  v_commission_rate numeric;
  v_rebate_rate numeric;
  v_commission_amount numeric;
  v_rebate_amount numeric;
  v_new_volume numeric;
  v_new_vip_level integer;
  v_leveraged_volume numeric;
BEGIN
  -- Check if user was referred by someone
  SELECT referred_by, created_at INTO v_referrer_id, v_referee_signup_date
  FROM user_profiles
  WHERE id = p_user_id;

  -- If no referrer, nothing to distribute
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;

  -- Get referrer stats (or create if doesn't exist)
  SELECT * INTO v_referrer_stats
  FROM referral_stats
  WHERE user_id = v_referrer_id;

  IF v_referrer_stats IS NULL THEN
    -- Initialize referrer stats
    INSERT INTO referral_stats (user_id, total_referrals)
    VALUES (v_referrer_id, 1)
    RETURNING * INTO v_referrer_stats;
  END IF;

  -- Get commission and rebate rates based on VIP level
  v_commission_rate := get_commission_rate(v_referrer_stats.vip_level);
  v_rebate_rate := get_rebate_rate(v_referrer_stats.vip_level);

  -- Calculate commission amount - BASED ON ACTUAL FEE (not leveraged)
  -- The fee is only charged on margin, so commission is % of that fee
  v_commission_amount := (p_fee_amount * v_commission_rate) / 100;

  -- Calculate leveraged volume for VIP progression (margin * leverage)
  v_leveraged_volume := p_trade_amount * p_leverage;

  -- Record the commission with leveraged volume for tracking
  INSERT INTO referral_commissions (
    referrer_id,
    referee_id,
    transaction_id,
    trade_amount,
    fee_amount,
    commission_rate,
    commission_amount,
    vip_level
  ) VALUES (
    v_referrer_id,
    p_user_id,
    p_transaction_id,
    v_leveraged_volume,  -- Volume includes leverage for VIP tracking
    p_fee_amount,        -- Actual fee paid (on margin only)
    v_commission_rate,
    v_commission_amount, -- Commission on actual fee (not leveraged)
    v_referrer_stats.vip_level
  );

  -- Update referrer's earnings and volume
  -- Volume uses leverage multiplier for VIP progression
  -- Earnings are based on actual fee commission
  v_new_volume := v_referrer_stats.total_volume_30d + v_leveraged_volume;
  v_new_vip_level := calculate_vip_level(v_new_volume);

  UPDATE referral_stats
  SET
    total_earnings = total_earnings + v_commission_amount,
    total_volume_30d = v_new_volume,
    total_volume_all_time = total_volume_all_time + v_leveraged_volume,
    this_month_earnings = this_month_earnings + v_commission_amount,
    vip_level = v_new_vip_level,
    updated_at = now()
  WHERE user_id = v_referrer_id;

  -- Add commission to referrer's wallet (actual commission earned)
  UPDATE wallets
  SET balance = balance + v_commission_amount,
      updated_at = now()
  WHERE user_id = v_referrer_id
    AND currency = 'USDT'
    AND wallet_type = 'spot';

  -- Record transaction for commission
  INSERT INTO transactions (
    user_id,
    type,
    currency,
    amount,
    status,
    created_at
  ) VALUES (
    v_referrer_id,
    'referral_commission',
    'USDT',
    v_commission_amount,
    'completed',
    now()
  );

  -- Handle rebate for referee (if within 30 days of signup)
  -- Rebate is also based on actual fee, not leveraged amount
  IF v_referee_signup_date + INTERVAL '30 days' > now() THEN
    v_rebate_amount := (p_fee_amount * v_rebate_rate) / 100;

    -- Record the rebate
    INSERT INTO referral_rebates (
      user_id,
      transaction_id,
      original_fee,
      rebate_rate,
      rebate_amount,
      expires_at
    ) VALUES (
      p_user_id,
      p_transaction_id,
      p_fee_amount,
      v_rebate_rate,
      v_rebate_amount,
      v_referee_signup_date + INTERVAL '30 days'
    );

    -- Add rebate to referee's wallet
    UPDATE wallets
    SET balance = balance + v_rebate_amount,
        updated_at = now()
    WHERE user_id = p_user_id
      AND currency = 'USDT'
      AND wallet_type = 'spot';

    -- Record transaction for rebate
    INSERT INTO transactions (
      user_id,
      type,
      currency,
      amount,
      status,
      created_at
    ) VALUES (
      p_user_id,
      'fee_rebate',
      'USDT',
      v_rebate_amount,
      'completed',
      now()
    );
  END IF;

END;
$$;
