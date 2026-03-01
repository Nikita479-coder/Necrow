/*
  # Integrate Affiliate Multi-Tier Commissions Into Trading

  ## Overview
  This migration integrates the affiliate commission distribution system
  into existing trading functions (swap, futures, etc.)

  ## Changes
  1. Updates swap execution to call affiliate distribution
  2. Updates futures position closing to call affiliate distribution
  3. Ensures all trading fees trigger affiliate payouts

  ## Security
  All functions maintain existing RLS and security definer settings
*/

-- Update the execute_swap function to distribute affiliate commissions
CREATE OR REPLACE FUNCTION execute_swap(
  p_user_id UUID,
  p_from_currency TEXT,
  p_to_currency TEXT,
  p_from_amount NUMERIC,
  p_to_amount NUMERIC,
  p_rate NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from_wallet_id UUID;
  v_to_wallet_id UUID;
  v_swap_id UUID;
  v_fee NUMERIC;
  v_referrer_id UUID;
  v_fee_rate NUMERIC := 0.001;
BEGIN
  SELECT id INTO v_from_wallet_id FROM wallets
  WHERE user_id = p_user_id AND currency = p_from_currency AND wallet_type = 'main';

  IF v_from_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (p_user_id, p_from_currency, 0, 'main')
    RETURNING id INTO v_from_wallet_id;
  END IF;

  SELECT id INTO v_to_wallet_id FROM wallets
  WHERE user_id = p_user_id AND currency = p_to_currency AND wallet_type = 'main';

  IF v_to_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (p_user_id, p_to_currency, 0, 'main')
    RETURNING id INTO v_to_wallet_id;
  END IF;

  UPDATE wallets SET balance = balance - p_from_amount, updated_at = now()
  WHERE id = v_from_wallet_id AND balance >= p_from_amount;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  v_fee := p_to_amount * v_fee_rate;

  UPDATE wallets SET balance = balance + (p_to_amount - v_fee), updated_at = now()
  WHERE id = v_to_wallet_id;

  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount, to_amount,
    rate, fee, order_type, status, executed_at
  ) VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount, p_to_amount,
    p_rate, v_fee, 'instant', 'executed', now()
  ) RETURNING id INTO v_swap_id;

  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, description, created_at)
  VALUES
    (p_user_id, 'swap', p_from_currency, -p_from_amount, 'completed', 'Swap from ' || p_from_currency, now()),
    (p_user_id, 'swap', p_to_currency, p_to_amount - v_fee, 'completed', 'Swap to ' || p_to_currency, now());

  SELECT referred_by INTO v_referrer_id FROM user_profiles WHERE id = p_user_id;

  IF v_referrer_id IS NOT NULL THEN
    UPDATE referral_stats
    SET
      total_volume_30d = COALESCE(total_volume_30d, 0) + p_to_amount,
      total_volume_all_time = COALESCE(total_volume_all_time, 0) + p_to_amount,
      updated_at = now()
    WHERE user_id = v_referrer_id;
  END IF;

  -- Distribute affiliate commissions across all tiers
  PERFORM distribute_multi_tier_commissions(
    p_trader_id := p_user_id,
    p_trade_amount := p_to_amount,
    p_fee_amount := v_fee,
    p_trade_id := v_swap_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'swap_id', v_swap_id,
    'from_amount', p_from_amount,
    'to_amount', p_to_amount - v_fee,
    'fee', v_fee
  );
END;
$$;

-- Update close_position to distribute affiliate commissions
CREATE OR REPLACE FUNCTION close_position(
  p_position_id UUID,
  p_close_price NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_pnl NUMERIC;
  v_fees NUMERIC;
  v_net_pnl NUMERIC;
  v_final_amount NUMERIC;
  v_funding_fees NUMERIC;
  v_liquidation_fee NUMERIC;
BEGIN
  SELECT * INTO v_position FROM futures_positions WHERE id = p_position_id AND status = 'open';

  IF v_position.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  v_pnl := CASE
    WHEN v_position.side = 'long' THEN
      (p_close_price - v_position.entry_price) * v_position.size
    WHEN v_position.side = 'short' THEN
      (v_position.entry_price - p_close_price) * v_position.size
  END;

  v_funding_fees := COALESCE(v_position.total_funding_fees, 0);
  v_liquidation_fee := 0;

  v_fees := v_position.total_fees + v_funding_fees + v_liquidation_fee;
  v_net_pnl := v_pnl - v_fees;
  v_final_amount := v_position.margin + v_net_pnl;

  UPDATE futures_positions
  SET
    status = 'closed',
    exit_price = p_close_price,
    pnl = v_pnl,
    realized_pnl = v_net_pnl,
    closed_at = now()
  WHERE id = p_position_id;

  IF v_final_amount > 0 THEN
    INSERT INTO wallets (user_id, currency, balance, wallet_type, created_at, updated_at)
    VALUES (v_position.user_id, 'USDT', v_final_amount, 'futures_margin', now(), now())
    ON CONFLICT (user_id, currency, wallet_type)
    DO UPDATE SET
      balance = EXCLUDED.balance + wallets.balance,
      updated_at = now();
  END IF;

  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, created_at)
  VALUES (
    v_position.user_id,
    'futures_close',
    'USDT',
    v_final_amount,
    'completed',
    now()
  );

  -- Distribute affiliate commissions
  PERFORM distribute_multi_tier_commissions(
    p_trader_id := v_position.user_id,
    p_trade_amount := v_position.size * p_close_price,
    p_fee_amount := v_fees,
    p_trade_id := p_position_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'pnl', v_pnl,
    'fees', v_fees,
    'net_pnl', v_net_pnl,
    'final_amount', v_final_amount
  );
END;
$$;
