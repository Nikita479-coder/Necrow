/*
  # Fix Locked Bonus Margin Tracking

  ## Problem
  When closing positions, margin was being returned to regular wallet instead of 
  back to locked bonus. Only PnL should affect wallets:
  - Positive PnL: Credit to regular wallet (withdrawable)
  - Negative PnL: Deduct from locked bonus
  - Margin: Should return to wherever it came from

  ## Solution
  1. Add column to track margin taken from locked bonus
  2. Update place_futures_order to track locked bonus usage
  3. Update close_position to return margin to correct source
*/

-- Add column to track margin from locked bonus
ALTER TABLE futures_positions 
ADD COLUMN IF NOT EXISTS margin_from_locked_bonus numeric DEFAULT 0;

-- Update place_futures_order to track locked bonus usage
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
  v_margin_from_regular numeric;
  v_margin_from_locked numeric;
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
  FROM user_leverage_limits WHERE user_id = p_user_id;
  
  IF v_user_leverage_limit IS NULL THEN
    v_user_leverage_limit := 20;
  END IF;

  IF p_leverage > v_user_leverage_limit THEN
    RETURN jsonb_build_object('success', false, 'error', 'Your maximum allowed leverage is ' || v_user_leverage_limit || 'x');
  END IF;

  SELECT * INTO v_trading_pair
  FROM trading_pairs_config WHERE pair = p_pair AND is_active = true;

  IF v_trading_pair IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trading pair not found or inactive');
  END IF;

  SELECT last_price INTO v_market_price FROM market_prices WHERE pair = p_pair;

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

  SELECT COALESCE(available_balance, 0) INTO v_available_balance
  FROM futures_margin_wallets WHERE user_id = p_user_id;

  IF v_available_balance IS NULL THEN
    v_available_balance := 0;
  END IF;

  v_locked_bonus_balance := COALESCE(get_user_locked_bonus_balance(p_user_id), 0);
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
    WHERE user_id = p_user_id AND pair = p_pair AND status = 'open' AND side != p_side;
    
    IF v_position IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'No open position to reduce');
    END IF;
  END IF;

  -- Calculate how much margin comes from each source
  -- First use regular balance for fees, then for margin
  v_deduct_from_regular := LEAST(v_available_balance, v_total_cost);
  v_deduct_from_locked := v_total_cost - v_deduct_from_regular;
  
  -- Track margin specifically (not fees)
  v_margin_from_regular := LEAST(v_available_balance - v_fee_amount, v_margin_amount);
  IF v_margin_from_regular < 0 THEN v_margin_from_regular := 0; END IF;
  v_margin_from_locked := v_margin_amount - v_margin_from_regular;

  IF p_order_type = 'market' THEN
    IF v_deduct_from_regular > 0 THEN
      UPDATE futures_margin_wallets
      SET available_balance = available_balance - v_deduct_from_regular, updated_at = now()
      WHERE user_id = p_user_id;
      
      IF NOT FOUND THEN
        INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
        VALUES (p_user_id, -v_deduct_from_regular, 0)
        ON CONFLICT (user_id) DO UPDATE SET
          available_balance = futures_margin_wallets.available_balance - v_deduct_from_regular,
          updated_at = now();
      END IF;
    END IF;

    IF v_deduct_from_locked > 0 THEN
      PERFORM apply_pnl_to_locked_bonus(p_user_id, -v_deduct_from_locked);
    END IF;

    INSERT INTO futures_positions (
      user_id, pair, side, entry_price, quantity, leverage,
      margin_mode, margin_allocated, margin_from_locked_bonus,
      stop_loss, take_profit, status, liquidation_price
    ) VALUES (
      p_user_id, p_pair, p_side, v_entry_price, p_quantity, p_leverage,
      p_margin_mode, v_margin_amount, v_margin_from_locked,
      p_stop_loss, p_take_profit, 'open', v_liquidation_price
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
      'margin_from_regular', v_margin_from_regular,
      'margin_from_locked_bonus', v_margin_from_locked,
      'message', upper(p_side) || ' position opened successfully'
    );

  ELSE
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

-- Update close_position to return margin to correct source
DROP FUNCTION IF EXISTS public.close_position(uuid, numeric, numeric);

CREATE OR REPLACE FUNCTION public.close_position(
  p_position_id uuid,
  p_close_quantity numeric DEFAULT NULL,
  p_close_price numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_position record;
  v_current_price numeric;
  v_pnl numeric;
  v_close_qty numeric;
  v_margin_return numeric;
  v_margin_from_locked_return numeric;
  v_margin_from_regular_return numeric;
  v_trading_fee numeric;
  v_oldest_locked_bonus_id uuid;
BEGIN
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id AND status = 'open'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  IF p_close_price IS NOT NULL AND p_close_price > 0 THEN
    v_current_price := p_close_price;
  ELSE
    SELECT last_price INTO v_current_price FROM market_prices WHERE pair = v_position.pair;
    IF v_current_price IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Could not get market price');
    END IF;
  END IF;

  IF p_close_quantity IS NOT NULL AND p_close_quantity > 0 THEN
    v_close_qty := LEAST(p_close_quantity, v_position.quantity);
  ELSE
    v_close_qty := v_position.quantity;
  END IF;

  -- Calculate PnL
  IF v_position.side = 'long' THEN
    v_pnl := (v_current_price - v_position.entry_price) * v_close_qty;
  ELSE
    v_pnl := (v_position.entry_price - v_current_price) * v_close_qty;
  END IF;

  v_trading_fee := (v_current_price * v_close_qty) * 0.0004;

  -- Calculate margin return proportionally
  IF v_close_qty = v_position.quantity THEN
    v_margin_return := v_position.margin_allocated;
    v_margin_from_locked_return := COALESCE(v_position.margin_from_locked_bonus, 0);
  ELSE
    v_margin_return := v_position.margin_allocated * (v_close_qty / v_position.quantity);
    v_margin_from_locked_return := COALESCE(v_position.margin_from_locked_bonus, 0) * (v_close_qty / v_position.quantity);
  END IF;
  
  v_margin_from_regular_return := v_margin_return - v_margin_from_locked_return;

  -- Update or close position
  IF v_close_qty = v_position.quantity THEN
    UPDATE futures_positions
    SET status = 'closed',
        realized_pnl = v_pnl,
        mark_price = v_current_price,
        cumulative_fees = COALESCE(cumulative_fees, 0) + v_trading_fee,
        closed_at = now()
    WHERE position_id = p_position_id;
  ELSE
    UPDATE futures_positions
    SET quantity = quantity - v_close_qty,
        margin_allocated = margin_allocated - v_margin_return,
        margin_from_locked_bonus = COALESCE(margin_from_locked_bonus, 0) - v_margin_from_locked_return,
        mark_price = v_current_price
    WHERE position_id = p_position_id;
  END IF;

  -- Return margin from regular wallet back to regular wallet
  IF v_margin_from_regular_return > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_margin_from_regular_return,
        updated_at = now()
    WHERE user_id = v_position.user_id;
    
    IF NOT FOUND THEN
      INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
      VALUES (v_position.user_id, v_margin_from_regular_return, 0)
      ON CONFLICT (user_id) DO UPDATE SET
        available_balance = futures_margin_wallets.available_balance + v_margin_from_regular_return,
        updated_at = now();
    END IF;
  END IF;

  -- Return margin from locked bonus back to locked bonus
  IF v_margin_from_locked_return > 0 THEN
    PERFORM apply_pnl_to_locked_bonus(v_position.user_id, v_margin_from_locked_return);
  END IF;

  -- Handle PnL
  IF v_pnl > 0 THEN
    -- PROFIT: Credit to regular wallet (withdrawable) minus fee
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + (v_pnl - v_trading_fee),
        updated_at = now()
    WHERE user_id = v_position.user_id;

    -- Track profits in locked bonus for withdrawal eligibility
    SELECT id INTO v_oldest_locked_bonus_id
    FROM locked_bonuses
    WHERE user_id = v_position.user_id AND status = 'active' AND expires_at > now()
    ORDER BY created_at ASC LIMIT 1;

    IF v_oldest_locked_bonus_id IS NOT NULL THEN
      UPDATE locked_bonuses
      SET realized_profits = realized_profits + v_pnl, updated_at = now()
      WHERE id = v_oldest_locked_bonus_id;
    END IF;
  ELSE
    -- LOSS: Deduct from locked bonus, fee from regular wallet
    IF v_pnl < 0 THEN
      PERFORM apply_pnl_to_locked_bonus(v_position.user_id, v_pnl);
    END IF;
    
    -- Deduct fee from regular wallet
    UPDATE futures_margin_wallets
    SET available_balance = available_balance - v_trading_fee,
        updated_at = now()
    WHERE user_id = v_position.user_id;
  END IF;

  -- Record fee
  INSERT INTO fee_collections (
    user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount, currency
  ) VALUES (
    v_position.user_id, p_position_id, 'taker', v_position.pair, 
    v_current_price * v_close_qty, 0.0004, v_trading_fee, 'USDT'
  );

  -- Record transaction
  INSERT INTO transactions (
    user_id, transaction_type, currency, amount, status, details
  ) VALUES (
    v_position.user_id, 'futures_close', 'USDT', v_pnl, 'completed',
    'Closed ' || v_position.pair || ' ' || upper(v_position.side) || '. PnL: ' || round(v_pnl, 2) || ' USDT'
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'closed_quantity', v_close_qty,
    'exit_price', v_current_price,
    'pnl', round(v_pnl, 8),
    'fee', round(v_trading_fee, 8),
    'margin_returned_to_wallet', round(v_margin_from_regular_return, 8),
    'margin_returned_to_locked_bonus', round(v_margin_from_locked_return, 8)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.place_futures_order(uuid, text, text, text, numeric, integer, text, numeric, numeric, numeric, numeric, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_position(uuid, numeric, numeric) TO authenticated;
