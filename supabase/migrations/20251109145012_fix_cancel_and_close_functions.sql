/*
  # Fix Cancel Order and Close Position Functions

  ## Description
  Fixes the cancel_futures_order function to use correct column names
  and ensures close_position function works properly.

  ## Changes
  1. Updates cancel_futures_order to use locked_balance (not used_margin)
  2. Ensures close_position function properly releases margin
  3. Both functions now correctly update the futures_margin_wallets table

  ## Column Structure
  futures_margin_wallets has:
  - available_balance: funds ready to use
  - locked_balance: funds locked for open orders/positions
  - NOT used_margin (this column doesn't exist)
*/

-- Fix cancel order function with correct column names
DROP FUNCTION IF EXISTS cancel_futures_order(uuid);

CREATE OR REPLACE FUNCTION cancel_futures_order(p_order_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_order record;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM futures_orders
  WHERE order_id = p_order_id
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;
  
  -- Only pending orders can be cancelled
  IF v_order.order_status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Cannot cancel order with status: %s', v_order.order_status)
    );
  END IF;
  
  -- Unlock the margin back to available balance
  UPDATE futures_margin_wallets
  SET available_balance = available_balance + v_order.margin_amount,
      locked_balance = locked_balance - v_order.margin_amount,
      updated_at = now()
  WHERE user_id = v_order.user_id;
  
  -- Update order status
  UPDATE futures_orders
  SET order_status = 'cancelled',
      updated_at = now()
  WHERE order_id = p_order_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Order cancelled successfully',
    'margin_unlocked', v_order.margin_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure close_position function exists and works correctly
DROP FUNCTION IF EXISTS close_position(uuid, numeric, numeric);

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
  v_close_price numeric;
  v_fee numeric;
  v_margin_to_release numeric;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Position not found'
    );
  END IF;
  
  IF v_position.status != 'open' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Position is not open'
    );
  END IF;
  
  -- Determine close quantity
  v_close_qty := COALESCE(p_close_quantity, v_position.quantity);
  
  -- Get close price (current mark price if not specified)
  IF p_close_price IS NOT NULL THEN
    v_close_price := p_close_price;
  ELSE
    SELECT mark_price INTO v_close_price
    FROM market_prices
    WHERE pair = v_position.pair;
    
    IF v_close_price IS NULL THEN
      v_close_price := v_position.mark_price;
    END IF;
  END IF;
  
  -- Calculate PnL
  IF v_position.side = 'long' THEN
    v_pnl := (v_close_price - v_position.entry_price) * v_close_qty;
  ELSE
    v_pnl := (v_position.entry_price - v_close_price) * v_close_qty;
  END IF;
  
  -- Calculate closing fee
  v_fee := calculate_trading_fee(v_position.pair, v_close_qty, v_close_price, false);
  v_pnl := v_pnl - v_fee;
  
  -- Calculate margin to release
  v_margin_to_release := (v_position.margin_allocated * v_close_qty) / v_position.quantity;
  
  -- Full close
  IF v_close_qty >= v_position.quantity THEN
    -- Update position as closed
    UPDATE futures_positions
    SET status = 'closed',
        close_price = v_close_price,
        realized_pnl = v_pnl,
        closed_at = now()
    WHERE position_id = p_position_id;
    
    -- Release margin + PnL
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_margin_to_release + v_pnl,
        locked_balance = locked_balance - v_margin_to_release,
        updated_at = now()
    WHERE user_id = v_position.user_id;
    
  ELSE
    -- Partial close - update position
    UPDATE futures_positions
    SET quantity = quantity - v_close_qty,
        margin_allocated = margin_allocated - v_margin_to_release,
        realized_pnl = COALESCE(realized_pnl, 0) + v_pnl,
        last_price_update = now()
    WHERE position_id = p_position_id;
    
    -- Release partial margin + PnL
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_margin_to_release + v_pnl,
        locked_balance = locked_balance - v_margin_to_release,
        updated_at = now()
    WHERE user_id = v_position.user_id;
  END IF;
  
  -- Record transaction
  INSERT INTO transactions (
    user_id, type, amount, currency, status, metadata
  )
  VALUES (
    v_position.user_id,
    'futures_close',
    v_pnl,
    'USDT',
    'completed',
    jsonb_build_object(
      'position_id', p_position_id,
      'pair', v_position.pair,
      'side', v_position.side,
      'quantity', v_close_qty,
      'entry_price', v_position.entry_price,
      'close_price', v_close_price,
      'pnl', v_pnl
    )
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'pnl', v_pnl,
    'close_price', v_close_price,
    'quantity_closed', v_close_qty
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;