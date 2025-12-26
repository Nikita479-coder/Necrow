/*
  # Update Place Futures Order to Use Unified Commission Routing

  1. Changes
    - Updates place_futures_order to use distribute_commissions_unified
    - This ensures opening fees respect the referrer's program choice (referral vs affiliate)
*/

CREATE OR REPLACE FUNCTION place_futures_order(
  p_user_id UUID,
  p_pair TEXT,
  p_side TEXT,
  p_order_type TEXT,
  p_quantity NUMERIC,
  p_leverage INTEGER,
  p_margin_mode TEXT DEFAULT 'cross',
  p_price NUMERIC DEFAULT NULL,
  p_trigger_price NUMERIC DEFAULT NULL,
  p_stop_loss NUMERIC DEFAULT NULL,
  p_take_profit NUMERIC DEFAULT NULL,
  p_reduce_only BOOLEAN DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_current_price NUMERIC;
  v_entry_price NUMERIC;
  v_notional_value NUMERIC;
  v_margin_usdt NUMERIC;
  v_liquidation_price NUMERIC;
  v_position_id UUID;
  v_futures_balance NUMERIC;
  v_locked_bonus_balance NUMERIC;
  v_locked_bonus_id UUID;
  v_margin_from_futures NUMERIC := 0;
  v_margin_from_locked NUMERIC := 0;
  v_total_available NUMERIC;
  v_trading_fee NUMERIC;
  v_margin_after_fee NUMERIC;
  v_maintenance_margin_rate NUMERIC := 0.005;
  v_transaction_id UUID;
BEGIN
  -- Validate side
  IF p_side NOT IN ('long', 'short') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid side. Must be long or short');
  END IF;

  -- Validate leverage
  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Leverage must be between 1 and 125');
  END IF;

  -- Get current price
  SELECT last_price INTO v_current_price FROM market_prices WHERE pair = p_pair;
  IF v_current_price IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trading pair not found');
  END IF;

  -- Determine entry price
  IF p_order_type = 'limit' AND p_price IS NOT NULL THEN
    v_entry_price := p_price;
  ELSE
    v_entry_price := v_current_price;
  END IF;

  -- Calculate position values
  v_notional_value := p_quantity * v_entry_price;
  v_margin_usdt := v_notional_value / p_leverage;

  -- Get futures wallet balance
  SELECT COALESCE(available_balance, 0) INTO v_futures_balance
  FROM futures_margin_wallets WHERE user_id = p_user_id;
  IF v_futures_balance IS NULL THEN
    v_futures_balance := 0;
  END IF;

  -- Get locked bonus balance
  SELECT id, current_amount INTO v_locked_bonus_id, v_locked_bonus_balance
  FROM locked_bonuses
  WHERE user_id = p_user_id AND status = 'active' AND expires_at > now()
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_locked_bonus_balance IS NULL THEN
    v_locked_bonus_balance := 0;
  END IF;

  v_total_available := v_futures_balance + v_locked_bonus_balance;

  -- Check sufficient balance
  IF v_total_available < v_margin_usdt THEN
    RETURN jsonb_build_object('success', false, 'error', 
      'Insufficient balance. Required: ' || round(v_margin_usdt, 2) || ' USDT, Available: ' || round(v_total_available, 2) || ' USDT');
  END IF;

  -- Calculate trading fee (0.04% taker fee)
  v_trading_fee := v_notional_value * 0.0004;
  v_margin_after_fee := v_margin_usdt - v_trading_fee;

  IF v_margin_after_fee <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 
      'Margin too small after fee deduction. Minimum margin: ' || round(v_trading_fee * 1.1, 2) || ' USDT');
  END IF;

  -- Determine margin source
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

  -- Deduct from futures wallet
  IF v_margin_from_futures > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance - v_margin_from_futures,
        locked_balance = locked_balance + v_margin_from_futures,
        updated_at = now()
    WHERE user_id = p_user_id;
  END IF;

  -- Deduct from locked bonus
  IF v_margin_from_locked > 0 THEN
    UPDATE locked_bonuses
    SET current_amount = current_amount - v_margin_from_locked,
        updated_at = now()
    WHERE id = v_locked_bonus_id;
  END IF;

  -- Calculate liquidation price
  IF p_side = 'long' THEN
    v_liquidation_price := v_entry_price * (1 - (1 / p_leverage) + v_maintenance_margin_rate);
  ELSE
    v_liquidation_price := v_entry_price * (1 + (1 / p_leverage) - v_maintenance_margin_rate);
  END IF;

  -- Create position
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

  -- Record transaction
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
  VALUES (p_user_id, 'futures_open', 'USDT', v_margin_usdt, 'completed',
    'Opened ' || p_pair || ' ' || upper(p_side) || ' ' || p_leverage || 'x. Margin: ' || 
    round(v_margin_after_fee, 2) || ' USDT (Fee: ' || round(v_trading_fee, 4) || ' USDT)')
  RETURNING id INTO v_transaction_id;

  -- Record opening fee
  INSERT INTO fee_collections (user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount, currency)
  VALUES (p_user_id, v_position_id, 'taker', p_pair, v_notional_value, 0.0004, v_trading_fee, 'USDT');

  -- Distribute commissions using unified router (checks referral vs affiliate)
  IF v_trading_fee > 0.0001 THEN
    PERFORM distribute_commissions_unified(
      p_trader_id := p_user_id,
      p_transaction_id := v_transaction_id,
      p_trade_amount := v_notional_value,
      p_fee_amount := v_trading_fee,
      p_leverage := p_leverage
    );
  END IF;

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
