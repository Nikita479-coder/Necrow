/*
  # Fix Place Futures Order - Use Frontend Price for Market Orders

  1. Changes
    - Add optional p_market_price parameter to place_futures_order
    - For market orders, use the frontend-provided price if available
    - Falls back to database price if not provided

  2. Reason
    - Frontend shows real-time WebSocket prices from Bybit
    - Database prices can be slightly stale (updated every few seconds)
    - Orders should execute at the price the user sees, not a stale DB price
*/

DROP FUNCTION IF EXISTS public.place_futures_order(uuid,text,text,text,numeric,integer,text,numeric,numeric,numeric,numeric,boolean);

CREATE OR REPLACE FUNCTION public.place_futures_order(
  p_user_id uuid,
  p_pair text,
  p_side text,
  p_order_type text,
  p_quantity numeric,
  p_leverage integer,
  p_margin_mode text DEFAULT 'cross',
  p_price numeric DEFAULT NULL,
  p_stop_loss numeric DEFAULT NULL,
  p_take_profit numeric DEFAULT NULL,
  p_reduce_only boolean DEFAULT false,
  p_market_price numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_current_price numeric;
  v_entry_price numeric;
  v_notional_value numeric;
  v_margin_usdt numeric;
  v_liquidation_price numeric;
  v_position_id uuid;
  v_futures_balance numeric;
  v_locked_bonus_balance numeric;
  v_locked_bonus_id uuid;
  v_margin_from_futures numeric := 0;
  v_margin_from_locked numeric := 0;
  v_total_available numeric;
  v_trading_fee numeric;
  v_margin_after_fee numeric;
  v_maintenance_margin_rate numeric := 0.005;
BEGIN
  IF p_side NOT IN ('long', 'short') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid side. Must be long or short');
  END IF;
  
  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Leverage must be between 1 and 125');
  END IF;

  IF p_market_price IS NOT NULL AND p_market_price > 0 THEN
    v_current_price := p_market_price;
  ELSE
    SELECT last_price INTO v_current_price FROM market_prices WHERE pair = p_pair;
    IF v_current_price IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Trading pair not found');
    END IF;
  END IF;

  IF p_order_type = 'limit' AND p_price IS NOT NULL THEN
    v_entry_price := p_price;
  ELSE
    v_entry_price := v_current_price;
  END IF;

  v_notional_value := p_quantity * v_entry_price;
  v_margin_usdt := v_notional_value / p_leverage;

  SELECT COALESCE(available_balance, 0) INTO v_futures_balance
  FROM futures_margin_wallets WHERE user_id = p_user_id;
  IF v_futures_balance IS NULL THEN
    v_futures_balance := 0;
  END IF;

  SELECT id, current_amount INTO v_locked_bonus_id, v_locked_bonus_balance
  FROM locked_bonuses
  WHERE user_id = p_user_id AND status = 'active' AND expires_at > now()
  ORDER BY created_at ASC
  LIMIT 1;
  
  IF v_locked_bonus_balance IS NULL THEN
    v_locked_bonus_balance := 0;
  END IF;

  v_total_available := v_futures_balance + v_locked_bonus_balance;

  IF v_total_available < v_margin_usdt THEN
    RETURN jsonb_build_object('success', false, 'error', 
      'Insufficient balance. Required: ' || round(v_margin_usdt, 2) || ' USDT, Available: ' || round(v_total_available, 2) || ' USDT');
  END IF;

  v_trading_fee := v_notional_value * 0.0004;
  v_margin_after_fee := v_margin_usdt - v_trading_fee;
  
  IF v_margin_after_fee <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 
      'Margin too small after fee deduction. Minimum margin: ' || round(v_trading_fee * 1.1, 2) || ' USDT');
  END IF;

  IF v_futures_balance >= v_margin_usdt THEN
    v_margin_from_futures := v_margin_usdt;
    v_margin_from_locked := 0;
  ELSIF v_futures_balance > 0 THEN
    v_margin_from_futures := v_futures_balance;
    v_margin_from_locked := v_margin_usdt - v_futures_balance;
  ELSE
    v_margin_from_futures := 0;
    v_margin_from_locked := v_margin_usdt;
  END IF;

  IF v_margin_from_futures > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance - v_margin_from_futures,
        locked_balance = locked_balance + v_margin_from_futures,
        updated_at = now()
    WHERE user_id = p_user_id;
  END IF;

  IF v_margin_from_locked > 0 THEN
    UPDATE locked_bonuses
    SET current_amount = current_amount - v_margin_from_locked,
        updated_at = now()
    WHERE id = v_locked_bonus_id;
  END IF;

  IF p_side = 'long' THEN
    v_liquidation_price := v_entry_price * (1 - (1 / p_leverage) + v_maintenance_margin_rate);
  ELSE
    v_liquidation_price := v_entry_price * (1 + (1 / p_leverage) - v_maintenance_margin_rate);
  END IF;

  INSERT INTO futures_positions (
    user_id, pair, side, quantity, entry_price, mark_price,
    leverage, margin_mode, margin_allocated, margin_from_locked_bonus,
    liquidation_price, take_profit, stop_loss, status, 
    unrealized_pnl, cumulative_fees
  ) VALUES (
    p_user_id, p_pair, p_side, p_quantity, v_entry_price, v_current_price,
    p_leverage, p_margin_mode, v_margin_after_fee, 
    CASE WHEN v_margin_from_locked > 0 THEN v_margin_from_locked - (v_trading_fee * (v_margin_from_locked / v_margin_usdt)) ELSE 0 END,
    v_liquidation_price, p_take_profit, p_stop_loss, 'open',
    0, v_trading_fee
  )
  RETURNING position_id INTO v_position_id;

  INSERT INTO fee_collections (user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount, currency)
  VALUES (p_user_id, v_position_id, 'taker', p_pair, v_notional_value, 0.0004, v_trading_fee, 'USDT');

  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
  VALUES (p_user_id, 'futures_open', 'USDT', v_margin_usdt, 'completed',
    'Opened ' || p_pair || ' ' || upper(p_side) || ' ' || p_leverage || 'x. Margin: ' || 
    round(v_margin_after_fee, 2) || ' USDT (Fee: ' || round(v_trading_fee, 4) || ' USDT)');

  RETURN jsonb_build_object(
    'success', true,
    'position_id', v_position_id,
    'pair', p_pair,
    'side', p_side,
    'quantity', round(p_quantity, 8),
    'entry_price', v_entry_price,
    'leverage', p_leverage,
    'margin_requested', round(v_margin_usdt, 2),
    'opening_fee', round(v_trading_fee, 6),
    'margin_allocated', round(v_margin_after_fee, 6),
    'margin_from_futures', round(v_margin_from_futures, 6),
    'margin_from_locked_bonus', round(v_margin_from_locked, 6),
    'liquidation_price', round(v_liquidation_price, 2),
    'notional_value', round(v_notional_value, 2)
  );
END;
$$;