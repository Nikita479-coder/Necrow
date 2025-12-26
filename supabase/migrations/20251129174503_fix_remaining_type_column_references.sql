/*
  # Fix Remaining Functions Using 'type' Column

  1. Changes
    - Fix execute_market_order function
    - Fix update_follower_balances function
    - Change all 'type' references to 'transaction_type'
*/

-- Fix execute_market_order function
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

  RETURN v_position_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Fix update_follower_balances function
CREATE OR REPLACE FUNCTION update_follower_balances(
  p_trader_trade_id uuid,
  p_pnl_percentage numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allocation RECORD;
  v_follower_pnl numeric;
  v_return_amount numeric;
  v_wallet_type text;
BEGIN
  FOR v_allocation IN
    SELECT 
      cta.*,
      cr.is_mock
    FROM copy_trade_allocations cta
    JOIN copy_relationships cr ON cr.id = cta.copy_relationship_id
    WHERE cta.trader_trade_id = p_trader_trade_id
    AND cta.status = 'open'
  LOOP
    v_follower_pnl := v_allocation.allocated_amount * (p_pnl_percentage / 100.0);
    v_return_amount := v_allocation.allocated_amount + v_follower_pnl;

    v_wallet_type := CASE WHEN v_allocation.is_mock THEN 'mock' ELSE 'main' END;

    UPDATE copy_trade_allocations
    SET 
      realized_pnl = v_follower_pnl,
      pnl_percentage = p_pnl_percentage,
      status = 'closed',
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_allocation.id;

    UPDATE wallets
    SET 
      balance = balance + v_return_amount,
      updated_at = NOW()
    WHERE user_id = v_allocation.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      confirmed_at
    ) VALUES (
      v_allocation.follower_id,
      'copy_trade_pnl',
      'USDT',
      v_follower_pnl,
      'completed',
      now()
    );
  END LOOP;
END;
$$;