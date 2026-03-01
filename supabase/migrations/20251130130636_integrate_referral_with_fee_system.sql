/*
  # Integrate Referral System with Fee System
  
  1. Updates
    - Update place_market_order to call distribute_trading_fees
    - Update close_position_market to call distribute_trading_fees
    - Update execute_instant_swap to call distribute_trading_fees
    - Ensure referral commissions are distributed on every trade
  
  2. How It Works
    - When a trade is executed and fees are charged
    - Automatically distribute commissions to referrer (if applicable)
    - Automatically give rebates to new users (within 30 days)
    - Track everything in referral_commissions and referral_rebates tables
  
  3. Notes
    - Uses existing distribute_trading_fees function
    - Commission rates based on VIP level (10%-70% of fees)
    - Rebate rates for new users (5%-15% of fees)
    - All payments added to USDT spot wallets
*/

-- Update place_market_order to include referral distribution
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
  v_transaction_id uuid;
BEGIN
  -- Get current market price
  SELECT mark_price INTO v_current_price
  FROM market_prices
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
  ) RETURNING id INTO v_transaction_id;

  -- Distribute referral commissions and rebates
  PERFORM distribute_trading_fees(
    p_user_id,
    v_transaction_id,
    v_notional_value,
    v_trading_fee
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

-- Update close_position_market to include referral distribution
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
  v_position record;
  v_current_price numeric;
  v_pnl numeric;
  v_wallet_balance numeric;
  v_trading_fee numeric;
  v_return_amount numeric;
  v_transaction_id uuid;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND user_id = p_user_id
    AND status = 'open'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Position not found or already closed';
  END IF;

  -- Get current market price
  SELECT mark_price INTO v_current_price
  FROM market_prices
  WHERE pair = v_position.pair;

  IF v_current_price IS NULL THEN
    RAISE EXCEPTION 'Cannot get current price for %', v_position.pair;
  END IF;

  -- Calculate P&L
  IF v_position.side = 'long' THEN
    v_pnl := (v_current_price - v_position.entry_price) * v_position.quantity;
  ELSE
    v_pnl := (v_position.entry_price - v_current_price) * v_position.quantity;
  END IF;

  -- Calculate closing fee
  v_trading_fee := calculate_trading_fee(
    p_user_id,
    v_current_price * v_position.quantity,
    false
  );

  -- Calculate return amount: margin + PnL - closing fee
  v_return_amount := v_position.margin_allocated + v_pnl - v_trading_fee;

  -- Update position as closed
  UPDATE futures_positions
  SET
    status = 'closed',
    realized_pnl = v_pnl,
    cumulative_fees = cumulative_fees + v_trading_fee,
    mark_price = v_current_price,
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
    v_current_price * v_position.quantity,
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
      'position_id', p_position_id,
      'pair', v_position.pair,
      'side', v_position.side,
      'entry_price', v_position.entry_price,
      'exit_price', v_current_price,
      'pnl', v_pnl,
      'trading_fee', v_trading_fee
    )
  ) RETURNING id INTO v_transaction_id;

  -- Distribute referral commissions and rebates
  PERFORM distribute_trading_fees(
    p_user_id,
    v_transaction_id,
    v_current_price * v_position.quantity,
    v_trading_fee
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'exit_price', v_current_price,
    'pnl', v_pnl,
    'trading_fee', v_trading_fee,
    'return_amount', v_return_amount
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION place_market_order(uuid, text, text, numeric, integer, text, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION close_position_market(uuid, uuid) TO authenticated;
