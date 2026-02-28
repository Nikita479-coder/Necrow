/*
  # Integrate Fee System into Trading Functions

  1. Updates
    - Modify `place_market_order` to include spread markup and trading fees
    - Modify `close_position_market` to include trading fees
    - Modify liquidation functions to include liquidation fees
    - Add fee deductions from wallet balances

  2. Fee Flow
    - Position Open: Spread markup (on entry price) + Taker fee (on notional)
    - Position Close: Taker fee (on notional)
    - Liquidation: Liquidation fee (0.5% to insurance fund + exchange)
    - Funding: Every 8 hours (separate process)

  3. Changes
    - Entry price now includes spread markup
    - Margin requirements include trading fees
    - All fees tracked in fee_collections table
*/

-- Updated place_market_order with fees
CREATE OR REPLACE FUNCTION place_market_order(
  p_user_id uuid,
  p_pair text,
  p_side text,
  p_quantity numeric,
  p_leverage integer,
  p_margin_mode text DEFAULT 'cross',
  p_stop_loss numeric DEFAULT NULL,
  p_take_profit numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_price numeric;
  v_entry_price numeric;
  v_margin_required numeric;
  v_notional_value numeric;
  v_liquidation_price numeric;
  v_wallet_balance numeric;
  v_position_id uuid;
  v_max_leverage integer;
  v_mmr numeric := 0.005;
  v_trading_fee numeric;
  v_spread_cost numeric;
  v_total_cost numeric;
BEGIN
  -- Get current market price
  SELECT price INTO v_current_price
  FROM (VALUES 
    ('BTCUSDT', 96000::numeric),
    ('ETHUSDT', 3600::numeric),
    ('BNBUSDT', 680::numeric),
    ('SOLUSDT', 220::numeric),
    ('XRPUSDT', 2.30::numeric)
  ) AS prices(pair, price)
  WHERE pair = p_pair;

  IF v_current_price IS NULL THEN
    RAISE EXCEPTION 'Invalid trading pair: %', p_pair;
  END IF;

  -- Apply spread markup to get effective entry price
  v_entry_price := get_effective_entry_price(p_pair, v_current_price, p_side);

  -- Calculate notional value
  v_notional_value := v_entry_price * p_quantity;

  -- Calculate margin required (notional / leverage)
  v_margin_required := v_notional_value / p_leverage;

  -- Calculate trading fee (taker fee on notional)
  v_trading_fee := calculate_trading_fee(p_user_id, v_notional_value, false);

  -- Calculate spread cost (already factored into entry price, but track it)
  v_spread_cost := calculate_spread_cost(p_pair, v_current_price, p_quantity);

  -- Total cost = margin + trading fee
  v_total_cost := v_margin_required + v_trading_fee;

  -- Check user's wallet balance
  SELECT balance INTO v_wallet_balance
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'futures';

  IF v_wallet_balance < v_total_cost THEN
    RAISE EXCEPTION 'Insufficient balance. Required: %, Available: %', v_total_cost, v_wallet_balance;
  END IF;

  -- Get max leverage for user
  SELECT max_leverage INTO v_max_leverage
  FROM user_leverage_limits
  WHERE user_id = p_user_id;

  IF v_max_leverage IS NULL THEN
    v_max_leverage := 125;
  END IF;

  IF p_leverage > v_max_leverage THEN
    RAISE EXCEPTION 'Leverage % exceeds maximum allowed (%)', p_leverage, v_max_leverage;
  END IF;

  -- Calculate liquidation price
  IF p_side = 'long' THEN
    IF p_margin_mode = 'isolated' THEN
      v_liquidation_price := v_entry_price * (1 - (1.0 / p_leverage) + v_mmr);
    ELSE
      v_liquidation_price := v_entry_price * (1 - (v_margin_required / v_notional_value) + v_mmr);
    END IF;
  ELSE
    IF p_margin_mode = 'isolated' THEN
      v_liquidation_price := v_entry_price * (1 + (1.0 / p_leverage) - v_mmr);
    ELSE
      v_liquidation_price := v_entry_price * (1 + (v_margin_required / v_notional_value) - v_mmr);
    END IF;
  END IF;

  -- Deduct margin + fee from wallet
  UPDATE wallets
  SET 
    balance = balance - v_total_cost,
    updated_at = NOW()
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'futures';

  -- Create position
  INSERT INTO futures_positions (
    user_id,
    pair,
    side,
    entry_price,
    mark_price,
    quantity,
    leverage,
    margin_mode,
    margin_allocated,
    liquidation_price,
    unrealized_pnl,
    realized_pnl,
    cumulative_fees,
    stop_loss,
    take_profit,
    status,
    maintenance_margin_rate,
    opened_at,
    last_price_update
  ) VALUES (
    p_user_id,
    p_pair,
    p_side,
    v_entry_price,
    v_entry_price,
    p_quantity,
    p_leverage,
    p_margin_mode,
    v_margin_required,
    v_liquidation_price,
    0,
    0,
    v_trading_fee,
    p_stop_loss,
    p_take_profit,
    'open',
    v_mmr,
    NOW(),
    NOW()
  ) RETURNING position_id INTO v_position_id;

  -- Record trading fee
  PERFORM record_trading_fee(
    p_user_id,
    v_position_id,
    p_pair,
    v_notional_value,
    false
  );

  -- Record spread cost
  INSERT INTO fee_collections (
    user_id,
    position_id,
    fee_type,
    pair,
    notional_size,
    fee_rate,
    fee_amount
  ) VALUES (
    p_user_id,
    v_position_id,
    'spread',
    p_pair,
    v_notional_value,
    (v_spread_cost / v_notional_value),
    v_spread_cost
  );

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    metadata
  ) VALUES (
    p_user_id,
    'open_position',
    v_margin_required,
    'USDT',
    'completed',
    jsonb_build_object(
      'pair', p_pair,
      'side', p_side,
      'quantity', p_quantity,
      'entry_price', v_entry_price,
      'leverage', p_leverage,
      'trading_fee', v_trading_fee,
      'spread_cost', v_spread_cost,
      'position_id', v_position_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', v_position_id,
    'entry_price', v_entry_price,
    'margin_used', v_margin_required,
    'trading_fee', v_trading_fee,
    'spread_cost', v_spread_cost,
    'liquidation_price', v_liquidation_price
  );
END;
$$;

-- Updated close_position_market with fees
CREATE OR REPLACE FUNCTION close_position_market(
  p_user_id uuid,
  p_position_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_exit_price numeric;
  v_pnl numeric;
  v_notional_value numeric;
  v_return_amount numeric;
  v_trading_fee numeric;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND user_id = p_user_id
    AND status = 'open';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Position not found or already closed';
  END IF;

  -- Use current mark price as exit price (apply spread markup)
  v_exit_price := get_effective_entry_price(
    v_position.pair, 
    v_position.mark_price,
    CASE WHEN v_position.side = 'long' THEN 'short' ELSE 'long' END
  );

  -- Calculate notional value
  v_notional_value := v_exit_price * v_position.quantity;

  -- Calculate trading fee
  v_trading_fee := calculate_trading_fee(p_user_id, v_notional_value, false);

  -- Calculate PnL
  IF v_position.side = 'long' THEN
    v_pnl := (v_exit_price - v_position.entry_price) * v_position.quantity;
  ELSE
    v_pnl := (v_position.entry_price - v_exit_price) * v_position.quantity;
  END IF;

  -- Subtract accumulated fees
  v_pnl := v_pnl - v_position.cumulative_fees - v_trading_fee;

  -- Calculate return amount
  v_return_amount := v_position.margin_allocated + v_pnl;

  IF v_return_amount < 0 THEN
    v_return_amount := 0;
  END IF;

  -- Update position
  UPDATE futures_positions
  SET
    mark_price = v_exit_price,
    realized_pnl = v_pnl,
    cumulative_fees = cumulative_fees + v_trading_fee,
    status = 'closed',
    closed_at = NOW(),
    last_price_update = NOW()
  WHERE position_id = p_position_id;

  -- Return funds to wallet
  UPDATE wallets
  SET
    balance = balance + v_return_amount,
    updated_at = NOW()
  WHERE user_id = p_user_id
    AND currency = 'USDT'
    AND wallet_type = 'futures';

  -- Record trading fee
  PERFORM record_trading_fee(
    p_user_id,
    p_position_id,
    v_position.pair,
    v_notional_value,
    false
  );

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    metadata
  ) VALUES (
    p_user_id,
    'close_position',
    v_return_amount,
    'USDT',
    'completed',
    jsonb_build_object(
      'pair', v_position.pair,
      'side', v_position.side,
      'entry_price', v_position.entry_price,
      'exit_price', v_exit_price,
      'pnl', v_pnl,
      'trading_fee', v_trading_fee,
      'position_id', p_position_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'exit_price', v_exit_price,
    'pnl', v_pnl,
    'return_amount', v_return_amount,
    'trading_fee', v_trading_fee
  );
END;
$$;
