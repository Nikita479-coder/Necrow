/*
  # Fix swap functions to use 'main' wallet type
  
  1. Changes
    - Drops and recreates swap functions to use 'main' instead of 'spot'
    - Updates execute_instant_swap, place_limit_swap_order, cancel_limit_swap_order, execute_limit_swap_order
    
  2. Notes
    - The wallets table only allows: 'main', 'assets', 'copy', 'futures'
    - Swap operations should use the 'main' wallet type
*/

-- Drop existing functions
DROP FUNCTION IF EXISTS execute_instant_swap(uuid, text, text, numeric);
DROP FUNCTION IF EXISTS place_limit_swap_order(uuid, text, text, numeric, numeric);
DROP FUNCTION IF EXISTS cancel_limit_swap_order(uuid, uuid);
DROP FUNCTION IF EXISTS execute_limit_swap_order(uuid);

-- Recreate execute_instant_swap with 'main' wallet type
CREATE FUNCTION execute_instant_swap(
  p_user_id uuid,
  p_from_currency text,
  p_to_currency text,
  p_from_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from_wallet record;
  v_to_wallet record;
  v_exchange_rate numeric;
  v_to_amount numeric;
  v_order_id uuid;
  v_fee_amount numeric;
  v_transaction_id uuid;
  v_to_usd_rate numeric;
  v_volume_usd numeric;
BEGIN
  IF p_from_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  IF p_from_currency = p_to_currency THEN
    RAISE EXCEPTION 'Cannot swap same currency';
  END IF;

  v_exchange_rate := get_swap_rate(p_from_currency, p_to_currency);

  IF v_exchange_rate <= 0 THEN
    RAISE EXCEPTION 'Exchange rate not available for % to %', p_from_currency, p_to_currency;
  END IF;

  v_to_amount := p_from_amount * v_exchange_rate;
  v_fee_amount := v_to_amount * 0.001;
  v_to_amount := v_to_amount - v_fee_amount;

  -- Ensure from wallet exists
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, p_from_currency, 'main', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Lock and check from wallet
  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id
    AND currency = p_from_currency
    AND wallet_type = 'main'
  FOR UPDATE;

  IF (v_from_wallet.balance) < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient available balance';
  END IF;

  -- Ensure to wallet exists
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, p_to_currency, 'main', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Deduct from source wallet
  UPDATE wallets
  SET balance = balance - p_from_amount, updated_at = now()
  WHERE user_id = p_user_id
    AND currency = p_from_currency
    AND wallet_type = 'main';

  -- Add to destination wallet
  UPDATE wallets
  SET balance = balance + v_to_amount, updated_at = now()
  WHERE user_id = p_user_id
    AND currency = p_to_currency
    AND wallet_type = 'main';

  -- Record swap order
  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount, to_amount,
    order_type, execution_rate, status, fee_amount, executed_at
  )
  VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount, v_to_amount,
    'market', v_exchange_rate, 'completed', v_fee_amount, now()
  )
  RETURNING order_id INTO v_order_id;

  -- Calculate volume in USD
  v_to_usd_rate := get_swap_rate(p_to_currency, 'USDT');
  v_volume_usd := v_to_amount * v_to_usd_rate;

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    fee,
    confirmed_at
  ) VALUES (
    p_user_id,
    'swap',
    p_to_currency,
    v_to_amount,
    'completed',
    v_fee_amount,
    now()
  ) RETURNING id INTO v_transaction_id;

  -- Update volume tracking
  INSERT INTO user_volume_tracking (user_id, volume_30d, last_updated)
  VALUES (p_user_id, v_volume_usd, now())
  ON CONFLICT (user_id) DO UPDATE SET
    volume_30d = user_volume_tracking.volume_30d + v_volume_usd,
    last_updated = now();

  -- Distribute fees and referral commissions
  PERFORM distribute_trading_fees(
    p_user_id,
    v_transaction_id,
    v_volume_usd,
    v_fee_amount,
    1
  );

  -- Recalculate VIP level immediately after swap
  PERFORM calculate_user_vip_level(p_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'to_amount', v_to_amount,
    'fee_amount', v_fee_amount,
    'execution_rate', v_exchange_rate
  );
END;
$$;

-- Recreate place_limit_swap_order with 'main' wallet type
CREATE FUNCTION place_limit_swap_order(
  p_user_id uuid,
  p_from_currency text,
  p_to_currency text,
  p_from_amount numeric,
  p_target_rate numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from_wallet record;
  v_order_id uuid;
  v_current_rate numeric;
BEGIN
  IF p_from_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  IF p_target_rate <= 0 THEN
    RAISE EXCEPTION 'Target rate must be greater than 0';
  END IF;

  -- Ensure from wallet exists
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, p_from_currency, 'main', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Lock and check from wallet
  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id
    AND currency = p_from_currency
    AND wallet_type = 'main'
  FOR UPDATE;

  IF v_from_wallet.balance < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  -- Reserve funds
  UPDATE wallets
  SET balance = balance - p_from_amount, updated_at = now()
  WHERE user_id = p_user_id
    AND currency = p_from_currency
    AND wallet_type = 'main';

  -- Create limit order
  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount,
    order_type, target_rate, status, created_at
  )
  VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount,
    'limit', p_target_rate, 'pending', now()
  )
  RETURNING order_id INTO v_order_id;

  v_current_rate := get_swap_rate(p_from_currency, p_to_currency);

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'current_rate', v_current_rate,
    'target_rate', p_target_rate
  );
END;
$$;

-- Recreate cancel_limit_swap_order with 'main' wallet type
CREATE FUNCTION cancel_limit_swap_order(p_order_id uuid, p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_order record;
BEGIN
  SELECT * INTO v_order
  FROM swap_orders
  WHERE order_id = p_order_id
    AND user_id = p_user_id
    AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found or already executed';
  END IF;

  -- Ensure wallet exists
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, v_order.from_currency, 'main', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Return reserved funds
  UPDATE wallets
  SET balance = balance + v_order.from_amount, updated_at = now()
  WHERE user_id = p_user_id
    AND currency = v_order.from_currency
    AND wallet_type = 'main';

  -- Cancel order
  UPDATE swap_orders
  SET status = 'cancelled', updated_at = now()
  WHERE order_id = p_order_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Recreate execute_limit_swap_order with 'main' wallet type
CREATE FUNCTION execute_limit_swap_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_order record;
  v_current_rate numeric;
  v_to_amount numeric;
  v_fee_amount numeric;
  v_transaction_id uuid;
  v_to_usd_rate numeric;
  v_volume_usd numeric;
BEGIN
  SELECT * INTO v_order
  FROM swap_orders
  WHERE order_id = p_order_id
    AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_current_rate := get_swap_rate(v_order.from_currency, v_order.to_currency);

  IF v_current_rate < v_order.target_rate THEN
    RETURN;
  END IF;

  v_to_amount := v_order.from_amount * v_current_rate;
  v_fee_amount := v_to_amount * 0.001;
  v_to_amount := v_to_amount - v_fee_amount;

  -- Ensure to wallet exists
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (v_order.user_id, v_order.to_currency, 'main', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Credit destination wallet
  UPDATE wallets
  SET balance = balance + v_to_amount, updated_at = now()
  WHERE user_id = v_order.user_id
    AND currency = v_order.to_currency
    AND wallet_type = 'main';

  -- Update order
  UPDATE swap_orders
  SET 
    status = 'completed',
    to_amount = v_to_amount,
    execution_rate = v_current_rate,
    fee_amount = v_fee_amount,
    executed_at = now(),
    updated_at = now()
  WHERE order_id = p_order_id;

  -- Calculate volume in USD
  v_to_usd_rate := get_swap_rate(v_order.to_currency, 'USDT');
  v_volume_usd := v_to_amount * v_to_usd_rate;

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    fee,
    confirmed_at
  ) VALUES (
    v_order.user_id,
    'swap',
    v_order.to_currency,
    v_to_amount,
    'completed',
    v_fee_amount,
    now()
  ) RETURNING id INTO v_transaction_id;

  -- Update volume tracking
  INSERT INTO user_volume_tracking (user_id, volume_30d, last_updated)
  VALUES (v_order.user_id, v_volume_usd, now())
  ON CONFLICT (user_id) DO UPDATE SET
    volume_30d = user_volume_tracking.volume_30d + v_volume_usd,
    last_updated = now();

  -- Distribute fees
  PERFORM distribute_trading_fees(
    v_order.user_id,
    v_transaction_id,
    v_volume_usd,
    v_fee_amount,
    1
  );

  -- Recalculate VIP level
  PERFORM calculate_user_vip_level(v_order.user_id);
END;
$$;
