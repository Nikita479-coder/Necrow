/*
  # Require Deposits Before Distributing Commissions

  1. Changes
    - Add deposit verification to commission distribution functions
    - Drop and recreate functions to update signatures
    - Only distribute commissions if referee has at least one completed deposit
    - Prevents fraud from users who trade without depositing real money

  2. Security
    - Checks transactions table for deposit with status='completed'
    - Applies to both referral and affiliate commission systems
*/

-- Helper function to check if user has made a deposit
CREATE OR REPLACE FUNCTION has_completed_deposit(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM transactions
    WHERE user_id = p_user_id
      AND transaction_type = 'deposit'
      AND status = 'completed'
  );
END;
$$;

-- Drop and recreate distribute_multi_tier_commissions
DROP FUNCTION IF EXISTS distribute_multi_tier_commissions(uuid, numeric, numeric, uuid);

CREATE OR REPLACE FUNCTION distribute_multi_tier_commissions(
  p_trader_id uuid,
  p_trade_amount numeric,
  p_fee_amount numeric,
  p_trade_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user uuid := p_trader_id;
  v_referrer_id uuid;
  v_level integer := 1;
  v_commission_rate numeric;
  v_commission_amount numeric;
  v_trader_email text;
BEGIN
  -- CRITICAL: Skip if trader hasn't made a completed deposit
  IF NOT has_completed_deposit(p_trader_id) THEN
    RETURN;
  END IF;

  SELECT email INTO v_trader_email
  FROM auth.users
  WHERE id = p_trader_id;

  WHILE v_level <= 5 LOOP
    SELECT referred_by INTO v_referrer_id
    FROM user_profiles
    WHERE id = v_current_user;
    
    IF v_referrer_id IS NULL THEN
      EXIT;
    END IF;
    
    v_commission_rate := CASE v_level
      WHEN 1 THEN 40.0
      WHEN 2 THEN 10.0
      WHEN 3 THEN 5.0
      WHEN 4 THEN 3.0
      WHEN 5 THEN 2.0
    END;
    
    v_commission_amount := (p_fee_amount * v_commission_rate) / 100;
    
    INSERT INTO affiliate_commissions (
      affiliate_id,
      trader_id,
      trade_id,
      tier_level,
      trade_amount,
      fee_amount,
      commission_rate,
      commission_amount
    ) VALUES (
      v_referrer_id,
      p_trader_id,
      p_trade_id,
      v_level,
      p_trade_amount,
      p_fee_amount,
      v_commission_rate,
      v_commission_amount
    );
    
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (v_referrer_id, 'USDT', 'main', 0)
    ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;
    
    UPDATE wallets
    SET balance = balance + v_commission_amount,
        updated_at = now()
    WHERE user_id = v_referrer_id
      AND currency = 'USDT'
      AND wallet_type = 'main';
    
    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      details,
      confirmed_at
    ) VALUES (
      v_referrer_id,
      'affiliate_commission',
      'USDT',
      v_commission_amount,
      'completed',
      format('Tier %s affiliate commission from network trading', v_level),
      now()
    );

    PERFORM send_notification(
      v_referrer_id,
      'affiliate_payout',
      format('Affiliate Payout: +%s USDT', ROUND(v_commission_amount, 2)),
      format('You earned %s USDT (%s%%) as Tier %s commission from your network. Trader: %s',
        ROUND(v_commission_amount, 2),
        ROUND(v_commission_rate, 0),
        v_level,
        COALESCE(SUBSTRING(v_trader_email FROM 1 FOR 3) || '***', 'User')
      ),
      jsonb_build_object(
        'commission_amount', v_commission_amount,
        'currency', 'USDT',
        'commission_rate', v_commission_rate,
        'tier_level', v_level,
        'trader_id', p_trader_id,
        'trader_email', COALESCE(SUBSTRING(v_trader_email FROM 1 FOR 3) || '***', 'User'),
        'trade_amount', p_trade_amount,
        'fee_amount', p_fee_amount
      )
    );
    
    v_current_user := v_referrer_id;
    v_level := v_level + 1;
  END LOOP;
END;
$$;

-- Update distribute_trading_fees to require deposits
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
  -- Skip if exclusive affiliate in upline
  IF has_exclusive_affiliate_in_upline(p_user_id) THEN
    RETURN;
  END IF;

  -- CRITICAL: Skip if user hasn't made a completed deposit
  IF NOT has_completed_deposit(p_user_id) THEN
    RETURN;
  END IF;

  SELECT referred_by, created_at INTO v_referrer_id, v_referee_signup_date
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;

  SELECT NOT EXISTS (
    SELECT 1 FROM referral_commissions WHERE referee_id = p_user_id
  ) INTO v_is_first_trade;

  SELECT email INTO v_referee_email
  FROM auth.users
  WHERE id = p_user_id;

  SELECT * INTO v_referrer_stats
  FROM referral_stats
  WHERE user_id = v_referrer_id
  FOR UPDATE;

  IF v_referrer_stats IS NULL THEN
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
    UPDATE referral_stats
    SET total_referrals = total_referrals + 1
    WHERE user_id = v_referrer_id;
    
    v_referrer_stats.total_referrals := v_referrer_stats.total_referrals + 1;
  END IF;

  v_commission_rate := get_commission_rate(v_referrer_stats.vip_level);
  v_rebate_rate := get_rebate_rate(v_referrer_stats.vip_level);

  v_commission_amount := (p_fee_amount * v_commission_rate) / 100;

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

  v_new_volume := v_referrer_stats.total_volume_30d + p_trade_amount;
  v_new_vip_level := calculate_vip_level(v_new_volume);

  UPDATE referral_stats
  SET
    total_earnings = total_earnings + v_commission_amount,
    total_volume_30d = v_new_volume,
    total_volume_all_time = total_volume_all_time + p_trade_amount,
    this_month_earnings = this_month_earnings + v_commission_amount,
    vip_level = v_new_vip_level,
    updated_at = now()
  WHERE user_id = v_referrer_id;

  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (v_referrer_id, 'USDT', 'main', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  UPDATE wallets
  SET balance = balance + v_commission_amount,
      updated_at = now()
  WHERE user_id = v_referrer_id
    AND currency = 'USDT'
    AND wallet_type = 'main';

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

  IF v_referee_signup_date + INTERVAL '30 days' > now() THEN
    v_rebate_amount := (p_fee_amount * v_rebate_rate) / 100;

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

    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_user_id, 'USDT', 'main', 0)
    ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

    UPDATE wallets
    SET balance = balance + v_rebate_amount,
        updated_at = now()
    WHERE user_id = p_user_id
      AND currency = 'USDT'
      AND wallet_type = 'main';

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

GRANT EXECUTE ON FUNCTION has_completed_deposit TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_trading_fees(uuid, uuid, numeric, numeric, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_multi_tier_commissions(uuid, numeric, numeric, uuid) TO authenticated;
