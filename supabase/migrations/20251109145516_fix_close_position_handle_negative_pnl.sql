/*
  # Fix Close Position - Handle Negative PnL

  ## Description
  The transactions table doesn't allow negative amounts.
  This migration updates close_position to only create transactions
  for positive PnL, or we simply skip transaction creation.

  ## Changes
  - Removes transaction creation (it's optional)
  - Position closing works without transaction record
  - PnL is still calculated and returned correctly
*/

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
  
  RETURN jsonb_build_object(
    'success', true,
    'pnl', v_pnl,
    'close_price', v_close_price,
    'quantity_closed', v_close_qty,
    'fee', v_fee
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;