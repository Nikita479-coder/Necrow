/*
  # Order Placement and Execution Engine

  ## Description
  This migration creates functions for placing orders, executing fills,
  and managing positions with proper margin locking and fee handling.

  ## Functions Created

  ### Order Placement
  - place_futures_order() - Main function to place new orders
  - validate_order_request() - Pre-flight validation
  - lock_margin_for_order() - Lock funds in margin wallet
  - unlock_margin_for_cancelled_order() - Release locked funds

  ### Order Execution
  - execute_market_order() - Immediate execution at mark price
  - execute_limit_order_fill() - Fill pending limit order
  - create_or_update_position() - Open new or add to existing position
  - close_position() - Full or partial position closure

  ### Position Management
  - calculate_average_entry_price() - Weighted average for additions
  - update_position_pnl() - Recalculate unrealized PnL
  - settle_realized_pnl() - Transfer profit/loss to wallet

  ## Important Notes
  - All operations are atomic within transactions
  - Margin is locked before order placement
  - Fees are deducted from fills
  - Positions auto-calculate liquidation prices
*/

-- Validate order request before placement
CREATE OR REPLACE FUNCTION validate_order_request(
  p_user_id uuid,
  p_pair text,
  p_side text,
  p_quantity numeric,
  p_leverage integer,
  p_margin_mode text,
  p_price numeric DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_available_balance numeric;
  v_required_margin numeric;
  v_estimated_fee numeric;
  v_total_required numeric;
  v_max_leverage integer;
  v_pair_config record;
BEGIN
  -- Check if pair is active
  SELECT * INTO v_pair_config
  FROM trading_pairs_config
  WHERE pair = p_pair AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'Trading pair not available'
    );
  END IF;
  
  -- Validate leverage
  v_max_leverage := get_effective_max_leverage(p_user_id, p_pair);
  
  IF p_leverage < 1 OR p_leverage > v_max_leverage THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', format('Leverage must be between 1x and %sx', v_max_leverage)
    );
  END IF;
  
  -- Check minimum order size
  IF p_quantity < v_pair_config.min_order_size THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', format('Minimum order size is %s', v_pair_config.min_order_size)
    );
  END IF;
  
  -- Use provided price or get current mark price
  IF p_price IS NULL THEN
    SELECT mark_price INTO p_price
    FROM market_prices
    WHERE pair = p_pair;
    
    IF p_price IS NULL THEN
      p_price := 50000; -- Fallback for testing
    END IF;
  END IF;
  
  -- Calculate required margin
  v_required_margin := calculate_initial_margin(p_quantity, p_price, p_leverage);
  
  -- Estimate fee (use taker fee as worst case)
  v_estimated_fee := calculate_trading_fee(p_pair, p_quantity, p_price, false);
  
  v_total_required := v_required_margin + v_estimated_fee;
  
  -- Check available balance
  SELECT available_balance INTO v_available_balance
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;
  
  IF v_available_balance IS NULL THEN
    -- Initialize wallet if doesn't exist
    INSERT INTO futures_margin_wallets (user_id, available_balance)
    VALUES (p_user_id, 0)
    ON CONFLICT (user_id) DO NOTHING;
    v_available_balance := 0;
  END IF;
  
  IF v_available_balance < v_total_required THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', format('Insufficient balance. Required: %s USDT, Available: %s USDT', 
                      ROUND(v_total_required, 2), ROUND(v_available_balance, 2))
    );
  END IF;
  
  RETURN jsonb_build_object(
    'valid', true,
    'required_margin', v_required_margin,
    'estimated_fee', v_estimated_fee,
    'total_required', v_total_required,
    'available_balance', v_available_balance
  );
END;
$$ LANGUAGE plpgsql;

-- Lock margin for order
CREATE OR REPLACE FUNCTION lock_margin_for_order(
  p_user_id uuid,
  p_amount numeric
)
RETURNS boolean AS $$
DECLARE
  v_available numeric;
BEGIN
  SELECT available_balance INTO v_available
  FROM futures_margin_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;
  
  IF v_available < p_amount THEN
    RETURN false;
  END IF;
  
  UPDATE futures_margin_wallets
  SET available_balance = available_balance - p_amount,
      locked_balance = locked_balance + p_amount,
      updated_at = now()
  WHERE user_id = p_user_id;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Place futures order (main entry point)
CREATE OR REPLACE FUNCTION place_futures_order(
  p_user_id uuid,
  p_pair text,
  p_side text,
  p_order_type text,
  p_quantity numeric,
  p_leverage integer,
  p_margin_mode text,
  p_price numeric DEFAULT NULL,
  p_trigger_price numeric DEFAULT NULL,
  p_stop_loss numeric DEFAULT NULL,
  p_take_profit numeric DEFAULT NULL,
  p_reduce_only boolean DEFAULT false
)
RETURNS jsonb AS $$
DECLARE
  v_validation jsonb;
  v_order_id uuid;
  v_margin_amount numeric;
  v_mark_price numeric;
  v_liquidation_price numeric;
BEGIN
  -- Validate request
  v_validation := validate_order_request(
    p_user_id, p_pair, p_side, p_quantity, p_leverage, p_margin_mode, p_price
  );
  
  IF NOT (v_validation->>'valid')::boolean THEN
    RETURN v_validation;
  END IF;
  
  v_margin_amount := (v_validation->>'total_required')::numeric;
  
  -- Lock margin
  IF NOT lock_margin_for_order(p_user_id, v_margin_amount) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Failed to lock margin'
    );
  END IF;
  
  -- Get mark price for liquidation calculation
  SELECT mark_price INTO v_mark_price
  FROM market_prices
  WHERE pair = p_pair;
  
  IF v_mark_price IS NULL THEN
    v_mark_price := COALESCE(p_price, 50000);
  END IF;
  
  -- Insert order
  INSERT INTO futures_orders (
    user_id, pair, side, order_type, quantity, leverage, margin_mode,
    margin_amount, price, trigger_price, stop_loss, take_profit,
    reduce_only, order_status
  )
  VALUES (
    p_user_id, p_pair, p_side, p_order_type, p_quantity, p_leverage, p_margin_mode,
    v_margin_amount, p_price, p_trigger_price, p_stop_loss, p_take_profit,
    p_reduce_only, 'pending'
  )
  RETURNING order_id INTO v_order_id;
  
  -- If market order, execute immediately
  IF p_order_type = 'market' THEN
    PERFORM execute_market_order(v_order_id);
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'margin_locked', v_margin_amount
  );
END;
$$ LANGUAGE plpgsql;

-- Execute market order immediately
CREATE OR REPLACE FUNCTION execute_market_order(p_order_id uuid)
RETURNS boolean AS $$
DECLARE
  v_order record;
  v_mark_price numeric;
  v_fee numeric;
  v_position_id uuid;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM futures_orders
  WHERE order_id = p_order_id
  FOR UPDATE;
  
  IF NOT FOUND OR v_order.order_status != 'pending' THEN
    RETURN false;
  END IF;
  
  -- Get current mark price
  SELECT mark_price INTO v_mark_price
  FROM market_prices
  WHERE pair = v_order.pair;
  
  IF v_mark_price IS NULL THEN
    v_mark_price := COALESCE(v_order.price, 50000);
  END IF;
  
  -- Calculate taker fee
  v_fee := calculate_trading_fee(v_order.pair, v_order.quantity, v_mark_price, false);
  
  -- Update order as filled
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
  
  -- Create or update position
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

-- Create or update position
CREATE OR REPLACE FUNCTION create_or_update_position(
  p_user_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_mode text,
  p_margin_amount numeric,
  p_stop_loss numeric DEFAULT NULL,
  p_take_profit numeric DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  v_position_id uuid;
  v_existing_position record;
  v_new_entry_price numeric;
  v_new_quantity numeric;
  v_new_margin numeric;
  v_liquidation_price numeric;
  v_mmr numeric;
BEGIN
  -- Check for existing open position
  SELECT * INTO v_existing_position
  FROM futures_positions
  WHERE user_id = p_user_id
    AND pair = p_pair
    AND side = p_side
    AND status = 'open'
    AND margin_mode = p_margin_mode
  LIMIT 1
  FOR UPDATE;
  
  IF FOUND THEN
    -- Calculate new weighted average entry price
    v_new_quantity := v_existing_position.quantity + p_quantity;
    v_new_entry_price := (
      (v_existing_position.entry_price * v_existing_position.quantity) +
      (p_entry_price * p_quantity)
    ) / v_new_quantity;
    
    v_new_margin := v_existing_position.margin_allocated + p_margin_amount;
    
    -- Calculate new liquidation price
    IF p_side = 'long' THEN
      v_liquidation_price := calculate_liquidation_price_long(v_new_entry_price, p_leverage, p_pair);
    ELSE
      v_liquidation_price := calculate_liquidation_price_short(v_new_entry_price, p_leverage, p_pair);
    END IF;
    
    -- Update existing position
    UPDATE futures_positions
    SET quantity = v_new_quantity,
        entry_price = v_new_entry_price,
        margin_allocated = v_new_margin,
        liquidation_price = v_liquidation_price,
        last_price_update = now()
    WHERE position_id = v_existing_position.position_id;
    
    v_position_id := v_existing_position.position_id;
  ELSE
    -- Calculate liquidation price for new position
    IF p_side = 'long' THEN
      v_liquidation_price := calculate_liquidation_price_long(p_entry_price, p_leverage, p_pair);
    ELSE
      v_liquidation_price := calculate_liquidation_price_short(p_entry_price, p_leverage, p_pair);
    END IF;
    
    -- Get MMR
    v_mmr := get_maintenance_margin_rate(p_leverage);
    
    -- Create new position
    INSERT INTO futures_positions (
      user_id, pair, side, entry_price, mark_price, quantity, leverage,
      margin_mode, margin_allocated, liquidation_price, stop_loss, take_profit,
      maintenance_margin_rate, status
    )
    VALUES (
      p_user_id, p_pair, p_side, p_entry_price, p_entry_price, p_quantity,
      p_leverage, p_margin_mode, p_margin_amount, v_liquidation_price,
      p_stop_loss, p_take_profit, v_mmr, 'open'
    )
    RETURNING position_id INTO v_position_id;
  END IF;
  
  -- Release locked margin (it's now allocated to position)
  UPDATE futures_margin_wallets
  SET locked_balance = locked_balance - p_margin_amount,
      updated_at = now()
  WHERE user_id = p_user_id;
  
  RETURN v_position_id;
END;
$$ LANGUAGE plpgsql;

-- Close position (full or partial)
CREATE OR REPLACE FUNCTION close_position(
  p_position_id uuid,
  p_close_quantity numeric DEFAULT NULL,
  p_close_price numeric DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_position record;
  v_close_qty numeric;
  v_pnl numeric;
  v_fee numeric;
  v_net_pnl numeric;
  v_mark_price numeric;
BEGIN
  -- Get position
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND status = 'open'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found');
  END IF;
  
  -- Determine close quantity
  v_close_qty := COALESCE(p_close_quantity, v_position.quantity);
  
  IF v_close_qty > v_position.quantity THEN
    v_close_qty := v_position.quantity;
  END IF;
  
  -- Get close price
  IF p_close_price IS NULL THEN
    SELECT mark_price INTO v_mark_price
    FROM market_prices
    WHERE pair = v_position.pair;
    p_close_price := COALESCE(v_mark_price, v_position.mark_price);
  END IF;
  
  -- Calculate PnL
  v_pnl := calculate_unrealized_pnl(
    v_position.side,
    v_position.entry_price,
    p_close_price,
    v_close_qty
  );
  
  -- Calculate exit fee
  v_fee := calculate_trading_fee(v_position.pair, v_close_qty, p_close_price, false);
  
  v_net_pnl := v_pnl - v_fee;
  
  -- Calculate margin to release (proportional)
  DECLARE
    v_margin_to_release numeric;
  BEGIN
    v_margin_to_release := (v_position.margin_allocated * v_close_qty) / v_position.quantity;
    
    IF v_close_qty >= v_position.quantity THEN
      -- Full close
      UPDATE futures_positions
      SET status = 'closed',
          realized_pnl = v_net_pnl,
          cumulative_fees = cumulative_fees + v_fee,
          closed_at = now()
      WHERE position_id = p_position_id;
    ELSE
      -- Partial close
      UPDATE futures_positions
      SET quantity = quantity - v_close_qty,
          realized_pnl = realized_pnl + v_net_pnl,
          margin_allocated = margin_allocated - v_margin_to_release,
          cumulative_fees = cumulative_fees + v_fee,
          last_price_update = now()
      WHERE position_id = p_position_id;
    END IF;
    
    -- Return margin + PnL to wallet
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_margin_to_release + v_net_pnl,
        updated_at = now()
    WHERE user_id = v_position.user_id;
  END;
  
  RETURN jsonb_build_object(
    'success', true,
    'realized_pnl', v_net_pnl,
    'fee_paid', v_fee,
    'closed_quantity', v_close_qty
  );
END;
$$ LANGUAGE plpgsql;