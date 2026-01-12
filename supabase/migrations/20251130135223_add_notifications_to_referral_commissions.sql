/*
  # Add Notifications to Referral Commission Payouts

  ## Summary
  Updates the distribute_trading_fees function to send a notification to the
  referrer every time they receive a commission payout from a referee's trading fee.

  ## Changes
  1. After adding commission to referrer's wallet, send a notification
  2. Include commission amount, referee info, and VIP level in notification
  3. Notification appears in real-time in the user's notification center

  ## Notification Details
  - Type: 'referral_payout'
  - Title: Shows amount earned
  - Message: Explains the commission from referee
  - Data: Contains commission amount, currency, VIP level, referee_id
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
  v_is_first_trade boolean := false;
  v_referee_email text;
BEGIN
  -- Check if user was referred by someone
  SELECT referred_by, created_at INTO v_referrer_id, v_referee_signup_date
  FROM user_profiles
  WHERE id = p_user_id;

  -- If no referrer, nothing to distribute
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;

  -- Check if this is referee's first trade (no existing commissions)
  SELECT NOT EXISTS (
    SELECT 1 FROM referral_commissions WHERE referee_id = p_user_id
  ) INTO v_is_first_trade;

  -- Get referee email for notification
  SELECT email INTO v_referee_email
  FROM auth.users
  WHERE id = p_user_id;

  -- Get or create referrer stats
  SELECT * INTO v_referrer_stats
  FROM referral_stats
  WHERE user_id = v_referrer_id
  FOR UPDATE;

  IF v_referrer_stats IS NULL THEN
    -- Initialize referrer stats
    INSERT INTO referral_stats (
      user_id, 
      vip_level,
      total_referrals, 
      total_earnings,
      this_month_earnings,
      total_volume_30d,
      total_volume_all_time
    ) VALUES (
      v_referrer_id, 
      1,
      CASE WHEN v_is_first_trade THEN 1 ELSE 0 END,
      0,
      0,
      0,
      0
    )
    RETURNING * INTO v_referrer_stats;
  ELSIF v_is_first_trade THEN
    -- Increment total_referrals for first trade
    UPDATE referral_stats
    SET total_referrals = total_referrals + 1
    WHERE user_id = v_referrer_id;
    
    v_referrer_stats.total_referrals := v_referrer_stats.total_referrals + 1;
  END IF;

  -- Get commission and rebate rates based on VIP level
  v_commission_rate := get_commission_rate(v_referrer_stats.vip_level);
  v_rebate_rate := get_rebate_rate(v_referrer_stats.vip_level);

  -- Calculate commission amount (percentage of trading fee)
  v_commission_amount := (p_fee_amount * v_commission_rate) / 100;

  -- Record the commission
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
    p_trade_amount,
    p_fee_amount,
    v_commission_rate,
    v_commission_amount,
    v_referrer_stats.vip_level
  );

  -- Calculate new volume and VIP level
  v_new_volume := v_referrer_stats.total_volume_30d + p_trade_amount;
  v_new_vip_level := calculate_vip_level(v_new_volume);

  -- Update referrer's earnings and volume
  UPDATE referral_stats
  SET
    total_earnings = total_earnings + v_commission_amount,
    total_volume_30d = v_new_volume,
    total_volume_all_time = total_volume_all_time + p_trade_amount,
    this_month_earnings = this_month_earnings + v_commission_amount,
    vip_level = v_new_vip_level,
    updated_at = now()
  WHERE user_id = v_referrer_id;

  -- Ensure referrer has a spot wallet (create if missing)
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (v_referrer_id, 'USDT', 'spot', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Add commission to referrer's spot wallet
  UPDATE wallets
  SET balance = balance + v_commission_amount,
      updated_at = now()
  WHERE user_id = v_referrer_id
    AND currency = 'USDT'
    AND wallet_type = 'spot';

  -- Record transaction for commission
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    confirmed_at
  ) VALUES (
    v_referrer_id,
    'referral_commission',
    'USDT',
    v_commission_amount,
    'completed',
    now()
  );

  -- Send notification to referrer about the commission payout
  PERFORM send_notification(
    v_referrer_id,
    'referral_payout',
    format('Referral Payout: +%s USDT', ROUND(v_commission_amount, 2)),
    format('You earned %s USDT (%s%%) commission from your referral''s trading fee. VIP Level: %s', 
      ROUND(v_commission_amount, 2),
      ROUND(v_commission_rate, 0),
      v_new_vip_level
    ),
    jsonb_build_object(
      'commission_amount', v_commission_amount,
      'currency', 'USDT',
      'commission_rate', v_commission_rate,
      'vip_level', v_new_vip_level,
      'referee_id', p_user_id,
      'referee_email', COALESCE(SUBSTRING(v_referee_email FROM 1 FOR 3) || '***', 'User'),
      'trade_amount', p_trade_amount,
      'fee_amount', p_fee_amount
    )
  );

  -- Handle rebate for referee (if within 30 days of signup)
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

    -- Ensure referee has a spot wallet (create if missing)
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_user_id, 'USDT', 'spot', 0)
    ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

    -- Add rebate to referee's spot wallet
    UPDATE wallets
    SET balance = balance + v_rebate_amount,
        updated_at = now()
    WHERE user_id = p_user_id
      AND currency = 'USDT'
      AND wallet_type = 'spot';

    -- Record transaction for rebate
    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      confirmed_at
    ) VALUES (
      p_user_id,
      'referral_rebate',
      'USDT',
      v_rebate_amount,
      'completed',
      now()
    );
  END IF;
END;
$$;