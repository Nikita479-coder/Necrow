/*
  # Fix All Functions to Use transaction_type Column

  1. Changes
    - Update all INSERT INTO transactions to use transaction_type instead of type
    - Fixes: distribute_trading_fees, admin_adjust_user_balance, unstake_tokens
*/

-- Fix distribute_trading_fees function
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
BEGIN
  SELECT referred_by, created_at INTO v_referrer_id, v_referee_signup_date
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_referrer_stats
  FROM referral_stats
  WHERE user_id = v_referrer_id;

  IF v_referrer_stats IS NULL THEN
    INSERT INTO referral_stats (user_id, total_referrals)
    VALUES (v_referrer_id, 1)
    RETURNING * INTO v_referrer_stats;
  END IF;

  v_commission_rate := get_commission_rate(v_referrer_stats.vip_level);
  v_rebate_rate := get_rebate_rate(v_referrer_stats.vip_level);
  v_commission_amount := (p_fee_amount * v_commission_rate) / 100;

  INSERT INTO referral_commissions (
    referrer_id, referee_id, transaction_id, trade_amount, fee_amount,
    commission_rate, commission_amount, vip_level
  ) VALUES (
    v_referrer_id, p_user_id, p_transaction_id, p_trade_amount, p_fee_amount,
    v_commission_rate, v_commission_amount, v_referrer_stats.vip_level
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

  UPDATE wallets
  SET balance = balance + v_commission_amount, updated_at = now()
  WHERE user_id = v_referrer_id AND currency = 'USDT' AND wallet_type = 'main';

  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, confirmed_at)
  VALUES (v_referrer_id, 'referral_commission', 'USDT', v_commission_amount, 'completed', now());

  IF v_referee_signup_date + INTERVAL '30 days' > now() THEN
    v_rebate_amount := (p_fee_amount * v_rebate_rate) / 100;

    INSERT INTO referral_rebates (
      user_id, transaction_id, original_fee, rebate_rate, rebate_amount, expires_at
    ) VALUES (
      p_user_id, p_transaction_id, p_fee_amount, v_rebate_rate, v_rebate_amount,
      v_referee_signup_date + INTERVAL '30 days'
    );

    UPDATE wallets
    SET balance = balance + v_rebate_amount, updated_at = now()
    WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = 'main';

    INSERT INTO transactions (user_id, transaction_type, currency, amount, status, confirmed_at)
    VALUES (p_user_id, 'fee_rebate', 'USDT', v_rebate_amount, 'completed', now());
  END IF;
END;
$$;

-- Fix admin_adjust_user_balance function
CREATE OR REPLACE FUNCTION admin_adjust_user_balance(
  p_user_id uuid,
  p_currency text,
  p_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet_record record;
  v_new_balance numeric;
  v_is_admin boolean;
BEGIN
  v_is_admin := COALESCE((auth.jwt()->>'is_admin')::boolean, false);

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
  END IF;

  IF p_amount IS NULL OR p_amount = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount cannot be zero or null');
  END IF;

  SELECT * INTO v_wallet_record
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_currency AND wallet_type = 'main';

  IF NOT FOUND THEN
    IF p_amount < 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Cannot create wallet with negative balance');
    END IF;

    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_user_id, p_currency, 'main', p_amount)
    RETURNING * INTO v_wallet_record;

    INSERT INTO transactions (user_id, transaction_type, amount, currency, status, confirmed_at)
    VALUES (p_user_id, 'deposit', p_amount, p_currency, 'completed', now());

    RETURN jsonb_build_object(
      'success', true,
      'message', format('Wallet created with balance: %s %s', p_amount, p_currency),
      'new_balance', p_amount,
      'wallet_created', true
    );
  END IF;

  v_new_balance := v_wallet_record.balance + p_amount;

  IF v_new_balance < 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Insufficient balance. Current: %s, Adjustment: %s', v_wallet_record.balance, p_amount)
    );
  END IF;

  UPDATE wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_record.id;

  INSERT INTO transactions (user_id, transaction_type, amount, currency, status, confirmed_at)
  VALUES (
    p_user_id,
    CASE WHEN p_amount > 0 THEN 'deposit' ELSE 'withdraw' END,
    abs(p_amount),
    p_currency,
    'completed',
    now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Balance adjusted successfully: %s %s', p_amount, p_currency),
    'old_balance', v_wallet_record.balance,
    'new_balance', v_new_balance,
    'adjustment', p_amount
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', format('Error adjusting balance: %s', SQLERRM));
END;
$$;

-- Fix unstake_tokens function
CREATE OR REPLACE FUNCTION unstake_tokens(stake_id_param uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  stake_record RECORD;
  main_wallet_record RECORD;
  assets_wallet_record RECORD;
  pending_rewards numeric;
  total_return numeric;
  early_unstake boolean := false;
BEGIN
  SELECT us.*, ep.coin INTO stake_record
  FROM user_stakes us
  JOIN earn_products ep ON us.product_id = ep.id
  WHERE us.id = stake_id_param AND us.status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stake not found or already redeemed');
  END IF;

  IF stake_record.end_date IS NOT NULL AND now() < stake_record.end_date THEN
    early_unstake := true;
  END IF;

  pending_rewards := calculate_stake_rewards(stake_id_param);
  total_return := stake_record.amount + pending_rewards;

  SELECT * INTO main_wallet_record
  FROM wallets
  WHERE user_id = stake_record.user_id 
    AND currency = stake_record.coin 
    AND wallet_type = 'main'
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (stake_record.user_id, stake_record.coin, 'main', 0)
    RETURNING * INTO main_wallet_record;
  END IF;

  SELECT * INTO assets_wallet_record
  FROM wallets
  WHERE user_id = stake_record.user_id 
    AND currency = stake_record.coin 
    AND wallet_type = 'assets'
  FOR UPDATE;

  UPDATE wallets
  SET balance = balance + total_return, updated_at = now()
  WHERE id = main_wallet_record.id;

  UPDATE wallets
  SET locked_balance = locked_balance - stake_record.amount, updated_at = now()
  WHERE id = assets_wallet_record.id;

  UPDATE user_stakes
  SET status = 'redeemed', earned_rewards = earned_rewards + pending_rewards, updated_at = now()
  WHERE id = stake_id_param;

  UPDATE earn_products
  SET invested_amount = GREATEST(invested_amount - stake_record.amount, 0), updated_at = now()
  WHERE id = stake_record.product_id;

  INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, confirmed_at)
  VALUES (stake_record.user_id, 'unstake', stake_record.coin, total_return, 0, 'completed', now());

  IF pending_rewards > 0 THEN
    INSERT INTO stake_rewards (stake_id, amount, reward_date)
    VALUES (stake_id_param, pending_rewards, now());
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'principal', stake_record.amount,
    'rewards', pending_rewards,
    'total', total_return,
    'early_unstake', early_unstake,
    'message', 'Successfully unstaked with total return: ' || total_return || ' ' || stake_record.coin
  );
END;
$$;