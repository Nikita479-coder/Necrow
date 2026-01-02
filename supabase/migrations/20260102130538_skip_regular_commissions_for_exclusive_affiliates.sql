/*
  # Skip Regular Commissions for Exclusive Affiliates

  ## Overview
  Modifies commission distribution logic to skip regular referral/affiliate commissions
  when an exclusive affiliate is in the user's upline. The exclusive affiliate system
  handles its own commission distribution separately.

  ## Important Notes
  - CPA bonuses (signup, KYC, first deposit, first trade) continue to work normally
  - Only trading fee and deposit commissions are affected
  - Exclusive affiliates receive commissions through the exclusive_affiliate_commissions table

  ## Functions
  1. `has_exclusive_affiliate_in_upline` - New helper to check for exclusive affiliates
  2. `distribute_commissions_unified` - Updated to skip if exclusive affiliate found
  3. `distribute_trading_fees` - Updated to skip if exclusive affiliate found
  4. Admin API functions for managing exclusive affiliates
*/

-- Helper function to check if any exclusive affiliate is in the user's upline
CREATE OR REPLACE FUNCTION has_exclusive_affiliate_in_upline(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user uuid := p_user_id;
  v_referrer_id uuid;
  v_level integer := 1;
BEGIN
  WHILE v_level <= 5 LOOP
    SELECT referred_by INTO v_referrer_id
    FROM user_profiles
    WHERE id = v_current_user;
    
    IF v_referrer_id IS NULL THEN
      RETURN false;
    END IF;
    
    IF EXISTS (
      SELECT 1 FROM exclusive_affiliates
      WHERE user_id = v_referrer_id AND is_active = true
    ) THEN
      RETURN true;
    END IF;
    
    v_current_user := v_referrer_id;
    v_level := v_level + 1;
  END LOOP;
  
  RETURN false;
END;
$$;

-- Update distribute_commissions_unified to skip for exclusive affiliates
CREATE OR REPLACE FUNCTION distribute_commissions_unified(
  p_trader_id UUID,
  p_transaction_id UUID,
  p_trade_amount NUMERIC,
  p_fee_amount NUMERIC,
  p_leverage INTEGER DEFAULT 1
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_referrer_id UUID;
  v_referrer_program TEXT;
BEGIN
  IF p_fee_amount <= 0 THEN
    RETURN;
  END IF;

  IF has_exclusive_affiliate_in_upline(p_trader_id) THEN
    RETURN;
  END IF;

  SELECT referred_by INTO v_referrer_id
  FROM user_profiles
  WHERE id = p_trader_id;

  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(active_program, 'referral') INTO v_referrer_program
  FROM user_profiles
  WHERE id = v_referrer_id;

  IF v_referrer_program = 'affiliate' THEN
    PERFORM distribute_multi_tier_commissions(
      p_trader_id := p_trader_id,
      p_trade_amount := p_trade_amount,
      p_fee_amount := p_fee_amount,
      p_trade_id := p_transaction_id
    );
  ELSE
    PERFORM distribute_trading_fees(
      p_user_id := p_trader_id,
      p_transaction_id := p_transaction_id,
      p_trade_amount := p_trade_amount,
      p_fee_amount := p_fee_amount,
      p_leverage := p_leverage
    );
  END IF;
END;
$$;

-- Update distribute_trading_fees to skip for exclusive affiliates
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
  IF has_exclusive_affiliate_in_upline(p_user_id) THEN
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

GRANT EXECUTE ON FUNCTION has_exclusive_affiliate_in_upline TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_commissions_unified TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_commissions_unified TO service_role;
GRANT EXECUTE ON FUNCTION distribute_trading_fees(uuid, uuid, numeric, numeric, integer) TO authenticated;

-- Admin function to get all exclusive affiliates with stats
CREATE OR REPLACE FUNCTION admin_get_exclusive_affiliates()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  email text,
  full_name text,
  username text,
  referral_code text,
  deposit_commission_rates jsonb,
  fee_share_rates jsonb,
  is_active boolean,
  enrolled_at timestamptz,
  enrolled_by_email text,
  available_balance numeric,
  pending_balance numeric,
  total_earned numeric,
  total_withdrawn numeric,
  deposit_commissions_earned numeric,
  fee_share_earned numeric,
  network_size integer,
  this_month_earnings numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT 
    ea.id,
    ea.user_id,
    au.email::text,
    up.full_name,
    up.username,
    up.referral_code,
    ea.deposit_commission_rates,
    ea.fee_share_rates,
    ea.is_active,
    ea.created_at as enrolled_at,
    (SELECT aue.email FROM auth.users aue WHERE aue.id = ea.enrolled_by)::text as enrolled_by_email,
    COALESCE(eab.available_balance, 0) as available_balance,
    COALESCE(eab.pending_balance, 0) as pending_balance,
    COALESCE(eab.total_earned, 0) as total_earned,
    COALESCE(eab.total_withdrawn, 0) as total_withdrawn,
    COALESCE(eab.deposit_commissions_earned, 0) as deposit_commissions_earned,
    COALESCE(eab.fee_share_earned, 0) as fee_share_earned,
    COALESCE(eans.level_1_count + eans.level_2_count + eans.level_3_count + eans.level_4_count + eans.level_5_count, 0)::integer as network_size,
    COALESCE(eans.this_month_earnings, 0) as this_month_earnings
  FROM exclusive_affiliates ea
  JOIN auth.users au ON au.id = ea.user_id
  LEFT JOIN user_profiles up ON up.id = ea.user_id
  LEFT JOIN exclusive_affiliate_balances eab ON eab.user_id = ea.user_id
  LEFT JOIN exclusive_affiliate_network_stats eans ON eans.affiliate_id = ea.user_id
  ORDER BY ea.created_at DESC;
END;
$$;

-- Admin function to get pending exclusive affiliate withdrawals
CREATE OR REPLACE FUNCTION admin_get_exclusive_withdrawals()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  email text,
  full_name text,
  amount numeric,
  currency text,
  wallet_address text,
  network text,
  status text,
  created_at timestamptz,
  processed_by_email text,
  processed_at timestamptz,
  rejection_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT 
    eaw.id,
    eaw.user_id,
    au.email::text,
    up.full_name,
    eaw.amount,
    eaw.currency,
    eaw.wallet_address,
    eaw.network,
    eaw.status,
    eaw.created_at,
    (SELECT aup.email FROM auth.users aup WHERE aup.id = eaw.processed_by)::text as processed_by_email,
    eaw.processed_at,
    eaw.rejection_reason
  FROM exclusive_affiliate_withdrawals eaw
  JOIN auth.users au ON au.id = eaw.user_id
  LEFT JOIN user_profiles up ON up.id = eaw.user_id
  ORDER BY 
    CASE WHEN eaw.status = 'pending' THEN 0 ELSE 1 END,
    eaw.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_exclusive_affiliates TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_exclusive_withdrawals TO authenticated;
