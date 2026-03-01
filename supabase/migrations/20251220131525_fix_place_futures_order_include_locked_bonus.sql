/*
  # Fix place_futures_order to include locked bonus balance
  
  The function was only checking futures_margin_wallets.available_balance
  but users may also have locked bonus balance that can be used for trading.
  
  Changes:
  - Include locked bonus balance when checking available funds
  - Properly deduct from regular balance first, then locked bonus
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
  v_locked_bonus_balance numeric;
  v_total_available numeric;
  v_market_price numeric;
  v_trading_pair record;
  v_user_leverage_limit integer;
  v_position record;
  v_fee_rate numeric := 0.0004;
  v_fee_amount numeric;
  v_total_cost numeric;
  v_notional_size numeric;
  v_liquidation_price numeric;
  v_maintenance_margin_rate numeric := 0.005;
  v_deduct_from_regular numeric;
  v_deduct_from_locked numeric;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF p_side NOT IN ('long', 'short') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid side. Must be long or short');
  END IF;

  IF p_order_type NOT IN ('market', 'limit') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid order type. Must be market or limit');
  END IF;

  IF p_margin_mode NOT IN ('cross', 'isolated') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid margin mode. Must be cross or isolated');
  END IF;

  IF p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be greater than 0');
  END IF;

  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Leverage must be between 1 and 125');
  END IF;

  SELECT max_allowed_leverage INTO v_user_leverage_limit
  FROM user_leverage_limits
  WHERE user_id = p_user_id;
  
  IF v_user_leverage_limit IS NULL THEN
    v_user_leverage_limit := 20;
  END IF;

  IF p_leverage > v_user_leverage_limit THEN
    RETURN jsonb_build_object('success', false, 'error', 'Your maximum allowed leverage is ' || v_user_leverage_limit || 'x');
  END IF;

  SELECT * INTO v_trading_pair
  FROM trading_pairs_config
  WHERE pair = p_pair AND is_active = true;

  IF v_trading_pair IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trading pair not found or inactive');
  END IF;

  SELECT last_price INTO v_market_price
  FROM market_prices
  WHERE pair = p_pair;

  IF v_market_price IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Could not get market price for ' || p_pair);
  END IF;

  IF p_order_type = 'market' THEN
    v_entry_price := v_market_price;
  ELSE
    IF p_price IS NULL OR p_price <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Limit price is required for limit orders');
    END IF;
    v_entry_price := p_price;
  END IF;

  v_notional_size := p_quantity * v_entry_price;
  v_margin_amount := v_notional_size / p_leverage;
  v_fee_amount := v_notional_size * v_fee_rate;
  v_total_cost := v_margin_amount + v_fee_amount;

  IF p_side = 'long' THEN
    v_liquidation_price := v_entry_price * (1 - (1.0 / p_leverage) + v_maintenance_margin_rate);
  ELSE
    v_liquidation_price := v_entry_price * (1 + (1.0 / p_leverage) - v_maintenance_margin_rate);
  END IF;

  -- Get regular available balance
  SELECT COALESCE(available_balance, 0) INTO v_available_balance
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  IF v_available_balance IS NULL THEN
    v_available_balance := 0;
  END IF;

  -- Get locked bonus balance
  v_locked_bonus_balance := COALESCE(get_user_locked_bonus_balance(p_user_id), 0);

  -- Total available for trading
  v_total_available := v_available_balance + v_locked_bonus_balance;

  IF v_total_available < v_total_cost THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Insufficient balance. Required: $' || round(v_total_cost, 2) || ', Available: $' || round(v_total_available, 2)
    );
  END IF;

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

  -- Calculate how much to deduct from each source
  -- Deduct from regular balance first
  v_deduct_from_regular := LEAST(v_available_balance, v_total_cost);
  v_deduct_from_locked := v_total_cost - v_deduct_from_regular;

  IF p_order_type = 'market' THEN
    -- Deduct from regular futures balance
    IF v_deduct_from_regular > 0 THEN
      UPDATE futures_margin_wallets
      SET available_balance = available_balance - v_deduct_from_regular,
          updated_at = now()
      WHERE user_id = p_user_id;
      
      -- Auto-create wallet if it doesn't exist
      IF NOT FOUND THEN
        INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
        VALUES (p_user_id, -v_deduct_from_regular, 0)
        ON CONFLICT (user_id) DO UPDATE SET
          available_balance = futures_margin_wallets.available_balance - v_deduct_from_regular,
          updated_at = now();
      END IF;
    END IF;

    -- Deduct from locked bonus if needed
    IF v_deduct_from_locked > 0 THEN
      PERFORM apply_pnl_to_locked_bonus(p_user_id, -v_deduct_from_locked);
    END IF;

    INSERT INTO futures_positions (
      user_id, pair, side, entry_price, quantity, leverage,
      margin_mode, margin_allocated, stop_loss, take_profit, status, liquidation_price
    ) VALUES (
      p_user_id, p_pair, p_side, v_entry_price, p_quantity, p_leverage,
      p_margin_mode, v_margin_amount, p_stop_loss, p_take_profit, 'open', v_liquidation_price
    ) RETURNING position_id INTO v_position_id;

    INSERT INTO fee_collections (
      user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount, currency
    ) VALUES (
      p_user_id, v_position_id, 'taker', p_pair, v_notional_size, v_fee_rate, v_fee_amount, 'USDT'
    );

    INSERT INTO transactions (
      user_id, transaction_type, currency, amount, status, details
    ) VALUES (
      p_user_id, 'futures_open', 'USDT', v_margin_amount, 'completed',
      upper(p_side) || ' ' || p_pair || ' position opened at $' || round(v_entry_price, 2)
    );

    RETURN jsonb_build_object(
      'success', true,
      'position_id', v_position_id,
      'entry_price', v_entry_price,
      'margin_used', v_margin_amount,
      'fee', v_fee_amount,
      'liquidation_price', v_liquidation_price,
      'used_from_regular', v_deduct_from_regular,
      'used_from_locked_bonus', v_deduct_from_locked,
      'message', upper(p_side) || ' position opened successfully'
    );

  ELSE
    -- For limit orders, only use regular balance (not locked bonus)
    IF v_available_balance < v_margin_amount THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', 'Limit orders require regular balance. Available: $' || round(v_available_balance, 2)
      );
    END IF;

    INSERT INTO futures_orders (
      user_id, pair, side, order_type, quantity, price, leverage,
      margin_mode, stop_loss, take_profit, order_status, margin_amount
    ) VALUES (
      p_user_id, p_pair, p_side, 'limit', p_quantity, p_price, p_leverage,
      p_margin_mode, p_stop_loss, p_take_profit, 'pending', v_margin_amount
    ) RETURNING order_id INTO v_order_id;

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
      'message', 'Limit ' || upper(p_side) || ' order placed at $' || round(p_price, 2)
    );
  END IF;
END;
$function$;
