/*
  # Fix Fees - Calculate Based on Margin Not Position Size

  1. Changes
    - Update place_futures_order to calculate fees based on margin instead of notional value
    - Update close_position to calculate fees based on margin instead of notional value
    - Update fee_collections to store margin instead of notional_size

  2. Rationale
    - Fees should be proportional to capital at risk (margin), not leveraged position size
    - Example: 20x leverage means fee is 1/20th of previous amount
    - More fair to traders using leverage
*/

-- Update place_futures_order function to calculate fee on margin
CREATE OR REPLACE FUNCTION public.place_futures_order(
  p_user_id uuid,
  p_pair text,
  p_side text,
  p_order_type text,
  p_quantity numeric,
  p_leverage integer,
  p_margin_mode text DEFAULT 'cross',
  p_price numeric DEFAULT NULL,
  p_trigger_price numeric DEFAULT NULL,
  p_stop_loss numeric DEFAULT NULL,
  p_take_profit numeric DEFAULT NULL,
  p_reduce_only boolean DEFAULT false
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
  v_transaction_id uuid;
BEGIN
  -- Validate inputs
  IF p_side NOT IN ('long', 'short') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid side. Must be long or short');
  END IF;

  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Leverage must be between 1 and 125');
  END IF;

  -- Get current market price
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

  -- Calculate margin from quantity (this is what frontend provides)
  v_notional_value := p_quantity * v_entry_price;
  v_margin_usdt := v_notional_value / p_leverage;

  -- Get available balances
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

  -- Check if user has enough balance
  IF v_total_available < v_margin_usdt THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Insufficient balance. Required: ' || round(v_margin_usdt, 2) || ' USDT, Available: ' || round(v_total_available, 2) || ' USDT');
  END IF;

  -- Calculate trading fee based on MARGIN, not notional value
  v_trading_fee := v_margin_usdt * 0.0004; -- 0.04% taker fee on margin

  -- Deduct fee from margin to get actual usable margin
  v_margin_after_fee := v_margin_usdt - v_trading_fee;

  IF v_margin_after_fee <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Margin too small after fee deduction. Minimum margin: ' || round(v_trading_fee * 1.1, 2) || ' USDT');
  END IF;

  -- Determine margin sources (deduct full original margin including fee)
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

  -- Deduct from futures wallet first
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

  -- Create position with fee-adjusted margin
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

  -- Record transaction FIRST
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
  VALUES (p_user_id, 'futures_open', 'USDT', v_margin_usdt, 'completed',
    'Opened ' || p_pair || ' ' || upper(p_side) || ' ' || p_leverage || 'x. Margin: ' ||
    round(v_margin_after_fee, 2) || ' USDT (Fee: ' || round(v_trading_fee, 4) || ' USDT)')
  RETURNING id INTO v_transaction_id;

  -- Record the opening fee (store margin as notional_size for clarity)
  INSERT INTO fee_collections (user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount, currency)
  VALUES (p_user_id, v_position_id, 'futures_open', p_pair, v_margin_usdt, 0.0004, v_trading_fee, 'USDT');

  -- Distribute fees through unified commission system
  PERFORM distribute_commissions(
    p_user_id,
    v_trading_fee,
    'futures_open',
    v_transaction_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', v_position_id,
    'pair', p_pair,
    'side', p_side,
    'quantity', round(p_quantity, 8),
    'entry_price', v_entry_price,
    'leverage', p_leverage,
    'margin_requested', round(v_margin_usdt, 2),
    'margin_allocated', round(v_margin_after_fee, 2),
    'fee', round(v_trading_fee, 4),
    'liquidation_price', round(v_liquidation_price, 2)
  );
END;
$$;

-- Update close_position function to calculate fee on margin
CREATE OR REPLACE FUNCTION public.close_position(
  p_position_id uuid,
  p_close_price numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_position RECORD;
  v_close_price numeric;
  v_pnl numeric;
  v_fee_amount numeric;
  v_fee_rate numeric;
  v_total_return numeric;
  v_margin_from_locked numeric;
  v_margin_from_futures numeric;
  v_transaction_id uuid;
BEGIN
  -- Get position details
  SELECT * INTO v_position FROM futures_positions WHERE position_id = p_position_id AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  -- Determine close price
  IF p_close_price IS NOT NULL THEN
    v_close_price := p_close_price;
  ELSE
    SELECT last_price INTO v_close_price FROM market_prices WHERE pair = v_position.pair;
  END IF;

  IF v_close_price IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unable to determine close price');
  END IF;

  -- Calculate PnL
  IF v_position.side = 'long' THEN
    v_pnl := v_position.quantity * (v_close_price - v_position.entry_price);
  ELSE
    v_pnl := v_position.quantity * (v_position.entry_price - v_close_price);
  END IF;

  -- Get fee rate for user
  SELECT COALESCE(taker_fee, 0.0004) INTO v_fee_rate
  FROM get_user_fee_rates(v_position.user_id);

  -- Calculate closing fee based on MARGIN, not notional value
  v_fee_amount := v_position.margin_allocated * v_fee_rate;

  -- Calculate total return (margin + pnl - fee)
  v_total_return := v_position.margin_allocated + v_pnl - v_fee_amount;

  -- Determine how much came from locked bonus
  v_margin_from_locked := COALESCE(v_position.margin_from_locked_bonus, 0);
  v_margin_from_futures := v_position.margin_allocated - v_margin_from_locked;

  -- Create transaction FIRST to get transaction_id
  INSERT INTO transactions (
    user_id, transaction_type, currency, amount, status, details
  ) VALUES (
    v_position.user_id, 'futures_close', 'USDT',
    v_total_return,
    'completed',
    format('Closed %s %s position. PnL: %s USDT', v_position.pair, UPPER(v_position.side),
           CASE WHEN v_pnl >= 0 THEN '+' ELSE '' END || round(v_pnl, 2))
  )
  RETURNING id INTO v_transaction_id;

  -- Update position
  UPDATE futures_positions
  SET
    status = 'closed',
    mark_price = v_close_price,
    realized_pnl = v_pnl,
    cumulative_fees = COALESCE(cumulative_fees, 0) + v_fee_amount,
    closed_at = now(),
    updated_at = now()
  WHERE position_id = p_position_id;

  -- Return margin to futures wallet (deducting fees from locked bonus proportionally)
  IF v_total_return > 0 THEN
    UPDATE futures_margin_wallets
    SET
      available_balance = available_balance + v_total_return,
      locked_balance = GREATEST(locked_balance - v_position.margin_allocated, 0),
      updated_at = now()
    WHERE user_id = v_position.user_id;
  ELSE
    -- If total loss, just unlock the margin
    UPDATE futures_margin_wallets
    SET
      locked_balance = GREATEST(locked_balance - v_position.margin_allocated, 0),
      updated_at = now()
    WHERE user_id = v_position.user_id;
  END IF;

  -- Record closing fee (store margin as notional_size)
  INSERT INTO fee_collections (
    user_id, position_id, fee_type, pair,
    notional_size, fee_rate, fee_amount, currency
  ) VALUES (
    v_position.user_id, p_position_id, 'futures_close', v_position.pair,
    v_position.margin_allocated, v_fee_rate, v_fee_amount, 'USDT'
  );

  -- Distribute closing fees through unified commission system
  PERFORM distribute_commissions(
    v_position.user_id,
    v_fee_amount,
    'futures_close',
    v_transaction_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'close_price', v_close_price,
    'pnl', round(v_pnl, 4),
    'fee', round(v_fee_amount, 4),
    'total_return', round(v_total_return, 4)
  );
END;
$$;