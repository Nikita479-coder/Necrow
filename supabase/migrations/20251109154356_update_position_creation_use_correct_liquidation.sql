/*
  # Update Position Creation to Use Correct Liquidation Calculation

  ## Description
  Modifies the create_or_update_position function to calculate liquidation prices
  correctly based on margin mode (cross vs isolated).

  ## Changes
  - Replace hardcoded isolated liquidation calculation
  - Use new calculate_liquidation_price() function
  - Pass user_id, current mark price, and margin mode
  - Ensures cross margin shows much lower (more aggressive) liquidation prices

  ## Important Notes
  - Cross margin liquidation prices will be significantly lower
  - Isolated margin liquidation prices remain unchanged
  - Liquidation price updates dynamically based on account equity
*/

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
  v_existing_position record;
  v_position_id uuid;
  v_new_quantity numeric;
  v_new_entry_price numeric;
  v_new_margin numeric;
  v_liquidation_price numeric;
  v_mmr numeric;
  v_mark_price numeric;
BEGIN
  -- Get current mark price
  SELECT mark_price INTO v_mark_price
  FROM market_prices
  WHERE pair = p_pair;
  
  v_mark_price := COALESCE(v_mark_price, p_entry_price);
  
  -- Check for existing position
  SELECT * INTO v_existing_position
  FROM futures_positions
  WHERE user_id = p_user_id
    AND pair = p_pair
    AND side = p_side
    AND status = 'open'
    AND margin_mode = p_margin_mode
  FOR UPDATE;
  
  IF FOUND THEN
    -- Update existing position (increase size)
    v_new_quantity := v_existing_position.quantity + p_quantity;
    
    -- Calculate weighted average entry price
    v_new_entry_price := (
      (v_existing_position.entry_price * v_existing_position.quantity) +
      (p_entry_price * p_quantity)
    ) / v_new_quantity;
    
    v_new_margin := v_existing_position.margin_allocated + p_margin_amount;
    
    -- Calculate new liquidation price using correct method
    v_liquidation_price := calculate_liquidation_price(
      p_user_id,
      p_side,
      v_new_entry_price,
      v_new_quantity,
      v_mark_price,
      p_leverage,
      p_margin_mode,
      p_pair
    );
    
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
    -- Calculate liquidation price for new position using correct method
    v_liquidation_price := calculate_liquidation_price(
      p_user_id,
      p_side,
      p_entry_price,
      p_quantity,
      v_mark_price,
      p_leverage,
      p_margin_mode,
      p_pair
    );
    
    -- Get MMR
    v_mmr := get_maintenance_margin_rate(p_leverage);
    
    -- Create new position
    INSERT INTO futures_positions (
      user_id, pair, side, entry_price, mark_price, quantity, leverage,
      margin_mode, margin_allocated, liquidation_price, stop_loss, take_profit,
      maintenance_margin_rate, status
    )
    VALUES (
      p_user_id, p_pair, p_side, p_entry_price, v_mark_price, p_quantity, p_leverage,
      p_margin_mode, p_margin_amount, v_liquidation_price, p_stop_loss, p_take_profit,
      v_mmr, 'open'
    )
    RETURNING position_id INTO v_position_id;
  END IF;
  
  RETURN v_position_id;
END;
$$ LANGUAGE plpgsql;