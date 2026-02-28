/*
  # Fix place_futures_order fee collection insert
  
  The fee_collections table requires:
  - notional_size (NOT NULL)
  - fee_rate (NOT NULL)
  - fee_type must be one of: spread, funding, maker, taker, liquidation
  
  Updated to use 'taker' fee type for market orders and include all required columns.
*/

DROP FUNCTION IF EXISTS public.place_futures_order(uuid, text, text, text, numeric, integer, text, numeric, numeric, numeric, numeric, boolean);

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
  p_trigger_price numeric DEFAULT NULL,
  p_reduce_only boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_order_id uuid;
  v_position_id uuid;
  v_entry_price numeric;
  v_margin_amount numeric;
  v_available_balance numeric;
  v_market_price numeric;
  v_trading_pair record;
  v_user_leverage_limit integer;
  v_position record;
  v_fee_rate numeric := 0.0004;
  v_fee_amount numeric;
  v_total_cost numeric;
  v_notional_size numeric;
BEGIN
  -- Validate user exists
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  -- Validate side
  IF p_side NOT IN ('long', 'short') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid side. Must be long or short');
  END IF;

  -- Validate order type
  IF p_order_type NOT IN ('market', 'limit') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid order type. Must be market or limit');
  END IF;

  -- Validate margin mode
  IF p_margin_mode NOT IN ('cross', 'isolated') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid margin mode. Must be cross or isolated');
  END IF;

  -- Validate quantity
  IF p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be greater than 0');
  END IF;

  -- Validate leverage range
  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Leverage must be between 1 and 125');
  END IF;

  -- Check user's leverage limit
  SELECT max_allowed_leverage INTO v_user_leverage_limit
  FROM user_leverage_limits
  WHERE user_id = p_user_id;
  
  IF v_user_leverage_limit IS NULL THEN
    v_user_leverage_limit := 20;
  END IF;

  IF p_leverage > v_user_leverage_limit THEN
    RETURN jsonb_build_object('success', false, 'error', format('Your maximum allowed leverage is %sx', v_user_leverage_limit));
  END IF;

  -- Check trading pair exists and is active
  SELECT * INTO v_trading_pair
  FROM trading_pairs_config
  WHERE pair = p_pair AND is_active = true;

  IF v_trading_pair IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trading pair not found or inactive');
  END IF;

  -- Get market price
  SELECT last_price INTO v_market_price
  FROM market_prices
  WHERE pair = p_pair;

  IF v_market_price IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Could not get market price for ' || p_pair);
  END IF;

  -- Determine entry price
  IF p_order_type = 'market' THEN
    v_entry_price := v_market_price;
  ELSE
    IF p_price IS NULL OR p_price <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Limit price is required for limit orders');
    END IF;
    v_entry_price := p_price;
  END IF;

  -- Calculate notional size, margin and fees
  v_notional_size := p_quantity * v_entry_price;
  v_margin_amount := v_notional_size / p_leverage;
  v_fee_amount := v_notional_size * v_fee_rate;
  v_total_cost := v_margin_amount + v_fee_amount;

  -- Check available balance
  SELECT COALESCE(available_balance, 0) INTO v_available_balance
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  IF v_available_balance IS NULL OR v_available_balance < v_total_cost THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', format('Insufficient balance. Required: $%.2f, Available: $%.2f', v_total_cost, COALESCE(v_available_balance, 0))
    );
  END IF;

  -- Handle reduce only orders
  IF p_reduce_only THEN
    SELECT * INTO v_position
    FROM futures_positions
    WHERE user_id = p_user_id 
      AND pair = p_pair 
      AND status = 'open'
      AND side != p_side;
    
    IF v_position IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'No open position to reduce');
    END IF;
  END IF;

  -- Execute market order immediately
  IF p_order_type = 'market' THEN
    -- Deduct from wallet
    UPDATE futures_margin_wallets
    SET available_balance = available_balance - v_total_cost,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Create position first to get position_id
    INSERT INTO futures_positions (
      user_id, pair, side, entry_price, quantity, leverage,
      margin_mode, margin_allocated, stop_loss, take_profit, status
    ) VALUES (
      p_user_id, p_pair, p_side, v_entry_price, p_quantity, p_leverage,
      p_margin_mode, v_margin_amount, p_stop_loss, p_take_profit, 'open'
    ) RETURNING position_id INTO v_position_id;

    -- Record fee with all required columns (using 'taker' for market orders)
    INSERT INTO fee_collections (
      user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount, currency
    ) VALUES (
      p_user_id, v_position_id, 'taker', p_pair, v_notional_size, v_fee_rate, v_fee_amount, 'USDT'
    );

    -- Record transaction
    INSERT INTO transactions (
      user_id, transaction_type, currency, amount, status, details
    ) VALUES (
      p_user_id, 'futures_open', 'USDT', v_margin_amount, 'completed',
      format('%s %s position opened at $%s', upper(p_side), p_pair, v_entry_price)
    );

    RETURN jsonb_build_object(
      'success', true,
      'position_id', v_position_id,
      'entry_price', v_entry_price,
      'margin_used', v_margin_amount,
      'fee', v_fee_amount,
      'message', format('%s position opened successfully', upper(p_side))
    );

  ELSE
    -- Create limit order
    INSERT INTO futures_orders (
      user_id, pair, side, order_type, quantity, price, leverage,
      margin_mode, stop_loss, take_profit, order_status, margin_amount
    ) VALUES (
      p_user_id, p_pair, p_side, 'limit', p_quantity, p_price, p_leverage,
      p_margin_mode, p_stop_loss, p_take_profit, 'pending', v_margin_amount
    ) RETURNING order_id INTO v_order_id;

    -- Reserve margin
    UPDATE futures_margin_wallets
    SET available_balance = available_balance - v_margin_amount,
        locked_balance = COALESCE(locked_balance, 0) + v_margin_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order_id,
      'order_type', 'limit',
      'price', p_price,
      'margin_reserved', v_margin_amount,
      'message', format('Limit %s order placed at $%s', upper(p_side), p_price)
    );
  END IF;
END;
$function$;
