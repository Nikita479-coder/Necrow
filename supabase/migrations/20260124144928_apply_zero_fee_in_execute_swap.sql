/*
  # Apply Zero Fee Promotion in Execute Swap

  1. Changes
    - Check if user has active zero fee promotion before calculating swap fee
    - If promotion is active, set swap fee to 0
    - Otherwise use normal 0.1% swap fee
*/

CREATE OR REPLACE FUNCTION execute_swap(
  p_user_id UUID,
  p_from_currency TEXT,
  p_to_currency TEXT,
  p_from_amount NUMERIC,
  p_to_amount NUMERIC,
  p_rate NUMERIC
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from_wallet_id UUID;
  v_to_wallet_id UUID;
  v_swap_id UUID;
  v_fee NUMERIC;
  v_referrer_id UUID;
  v_fee_rate NUMERIC := 0.001; -- 0.1% swap fee
  v_has_zero_fee_promo BOOLEAN := false;
BEGIN
  -- CHECK FOR ZERO FEE PROMOTION
  v_has_zero_fee_promo := check_user_zero_fee_active(p_user_id);

  IF v_has_zero_fee_promo THEN
    v_fee_rate := 0;
  END IF;

  -- Get or create from wallet
  SELECT id INTO v_from_wallet_id FROM wallets
  WHERE user_id = p_user_id AND currency = p_from_currency AND wallet_type = 'main';

  IF v_from_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (p_user_id, p_from_currency, 0, 'main')
    RETURNING id INTO v_from_wallet_id;
  END IF;

  -- Get or create to wallet
  SELECT id INTO v_to_wallet_id FROM wallets
  WHERE user_id = p_user_id AND currency = p_to_currency AND wallet_type = 'main';

  IF v_to_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (p_user_id, p_to_currency, 0, 'main')
    RETURNING id INTO v_to_wallet_id;
  END IF;

  -- Deduct from source wallet
  UPDATE wallets SET balance = balance - p_from_amount, updated_at = now()
  WHERE id = v_from_wallet_id AND balance >= p_from_amount;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Calculate fee (0 if promo active)
  v_fee := p_to_amount * v_fee_rate;

  -- Credit to destination wallet (minus fee)
  UPDATE wallets SET balance = balance + (p_to_amount - v_fee), updated_at = now()
  WHERE id = v_to_wallet_id;

  -- Create swap order record
  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount, to_amount,
    rate, fee, order_type, status, executed_at
  ) VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount, p_to_amount,
    p_rate, v_fee, 'instant', 'executed', now()
  ) RETURNING id INTO v_swap_id;

  -- Record transactions
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, description, created_at)
  VALUES
    (p_user_id, 'swap', p_from_currency, -p_from_amount, 'completed', 
     'Swap from ' || p_from_currency || CASE WHEN v_has_zero_fee_promo THEN ' (Zero Fee Promo)' ELSE '' END, now()),
    (p_user_id, 'swap', p_to_currency, p_to_amount - v_fee, 'completed', 
     'Swap to ' || p_to_currency, now());

  -- Update referrer volume stats
  SELECT referred_by INTO v_referrer_id FROM user_profiles WHERE id = p_user_id;

  IF v_referrer_id IS NOT NULL THEN
    UPDATE referral_stats
    SET
      total_volume_30d = COALESCE(total_volume_30d, 0) + p_to_amount,
      total_volume_all_time = COALESCE(total_volume_all_time, 0) + p_to_amount,
      updated_at = now()
    WHERE user_id = v_referrer_id;
  END IF;

  -- Only distribute commissions if there's an actual fee
  IF v_fee > 0 THEN
    PERFORM distribute_commissions_unified(
      p_trader_id := p_user_id,
      p_transaction_id := v_swap_id,
      p_trade_amount := p_to_amount,
      p_fee_amount := v_fee,
      p_leverage := 1
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'swap_id', v_swap_id,
    'from_amount', p_from_amount,
    'to_amount', p_to_amount - v_fee,
    'fee', v_fee,
    'zero_fee_promo', v_has_zero_fee_promo
  );
END;
$$;
