/*
  # Add Automatic VIP Recalculation on Trade Execution

  1. Changes
    - Update execute_market_order to recalculate VIP level after trade
    - Update execute_limit_order to recalculate VIP level after trade
    - Update execute_instant_swap to recalculate VIP level after swap
    - VIP levels now update immediately when trades are made

  2. Purpose
    - Users get instant VIP level updates based on their trading activity
    - No need to wait for daily cron job
    - Real-time tier progression and benefits
*/

-- Update execute_market_order to include VIP recalculation
CREATE OR REPLACE FUNCTION execute_market_order(p_order_id uuid)
RETURNS boolean AS $$
DECLARE
  v_order record;
  v_mark_price numeric;
  v_position_id uuid;
  v_fee numeric;
  v_transaction_id uuid;
BEGIN
  SELECT * INTO v_order
  FROM futures_orders
  WHERE order_id = p_order_id
  FOR UPDATE;

  IF NOT FOUND OR v_order.order_status != 'pending' THEN
    RETURN false;
  END IF;

  SELECT mark_price INTO v_mark_price
  FROM market_prices
  WHERE pair = v_order.pair;

  IF v_mark_price IS NULL THEN
    v_mark_price := COALESCE(v_order.price, 50000);
  END IF;

  v_fee := calculate_trading_fee(v_order.pair, v_order.quantity, v_mark_price, false);

  UPDATE futures_orders
  SET order_status = 'filled',
      filled_quantity = quantity,
      remaining_quantity = 0,
      average_fill_price = v_mark_price,
      maker_or_taker = 'taker',
      fee_paid = v_fee,
      filled_at = now(),
      updated_at = now()
  WHERE order_id = p_order_id;

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
    'open_position',
    'USDT',
    v_order.margin_amount,
    'completed',
    v_fee,
    now()
  ) RETURNING id INTO v_transaction_id;

  PERFORM distribute_trading_fees(
    v_order.user_id,
    v_transaction_id,
    v_order.margin_amount,
    v_fee,
    v_order.leverage
  );

  v_position_id := create_or_update_position(
    v_order.user_id,
    v_order.pair,
    v_order.side,
    v_mark_price,
    v_order.quantity,
    v_order.leverage,
    v_order.margin_mode,
    v_order.margin_amount - v_fee,
    v_order.stop_loss,
    v_order.take_profit
  );

  -- Recalculate VIP level immediately after trade
  PERFORM calculate_user_vip_level(v_order.user_id);

  RETURN v_position_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Update execute_limit_order to include VIP recalculation
CREATE OR REPLACE FUNCTION execute_limit_order(
  p_order_id uuid,
  p_execution_price numeric
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_fee numeric;
  v_position_id uuid;
  v_transaction_id uuid;
BEGIN
  SELECT * INTO v_order
  FROM futures_orders
  WHERE order_id = p_order_id
    AND order_status = 'pending'
    AND order_type = 'limit'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  v_fee := calculate_trading_fee(v_order.pair, v_order.quantity, p_execution_price, true);

  UPDATE futures_orders
  SET
    order_status = 'filled',
    filled_quantity = quantity,
    remaining_quantity = 0,
    average_fill_price = p_execution_price,
    maker_or_taker = 'maker',
    fee_paid = v_fee,
    filled_at = now(),
    updated_at = now()
  WHERE order_id = p_order_id;

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
    'open_position',
    'USDT',
    v_order.margin_amount,
    'completed',
    v_fee,
    now()
  ) RETURNING id INTO v_transaction_id;

  PERFORM distribute_trading_fees(
    v_order.user_id,
    v_transaction_id,
    v_order.margin_amount,
    v_fee,
    v_order.leverage
  );

  v_position_id := create_or_update_position(
    v_order.user_id,
    v_order.pair,
    v_order.side,
    p_execution_price,
    v_order.quantity,
    v_order.leverage,
    v_order.margin_mode,
    v_order.margin_amount - v_fee,
    v_order.stop_loss,
    v_order.take_profit
  );

  -- Recalculate VIP level immediately after trade
  PERFORM calculate_user_vip_level(v_order.user_id);

  RETURN v_position_id IS NOT NULL;
END;
$$;

-- Update execute_instant_swap to include VIP recalculation
CREATE OR REPLACE FUNCTION execute_instant_swap(
  p_user_id uuid,
  p_from_currency text,
  p_to_currency text,
  p_from_amount numeric
)
RETURNS jsonb AS $$
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

  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, p_from_currency, 'spot', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id
    AND currency = p_from_currency
    AND wallet_type = 'spot'
  FOR UPDATE;

  IF (v_from_wallet.balance) < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient available balance';
  END IF;

  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, p_to_currency, 'spot', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  UPDATE wallets
  SET balance = balance - p_from_amount, updated_at = now()
  WHERE user_id = p_user_id
    AND currency = p_from_currency
    AND wallet_type = 'spot';

  UPDATE wallets
  SET balance = balance + v_to_amount, updated_at = now()
  WHERE user_id = p_user_id
    AND currency = p_to_currency
    AND wallet_type = 'spot';

  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount, to_amount,
    order_type, execution_rate, status, fee_amount, executed_at
  )
  VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount, v_to_amount,
    'market', v_exchange_rate, 'completed', v_fee_amount, now()
  )
  RETURNING order_id INTO v_order_id;

  v_to_usd_rate := get_swap_rate(p_to_currency, 'USDT');
  v_volume_usd := v_to_amount * v_to_usd_rate;

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

  INSERT INTO user_volume_tracking (user_id, volume_30d, last_updated)
  VALUES (p_user_id, v_volume_usd, now())
  ON CONFLICT (user_id) DO UPDATE SET
    volume_30d = user_volume_tracking.volume_30d + v_volume_usd,
    last_updated = now();

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;