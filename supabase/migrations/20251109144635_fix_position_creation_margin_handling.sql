/*
  # Fix Position Creation Margin Handling

  ## Description
  This migration fixes the margin handling when creating positions from filled orders.
  The issue was that create_or_update_position was trying to unlock margin from
  locked_balance, but the margin was already in used_margin (locked by lock_margin_for_order).

  ## Changes
  - Updates create_or_update_position to move margin from used_margin (not locked_balance)
  - The margin stays as used_margin for the position
  - This prevents the constraint violation on locked_balance

  ## Important Notes
  The flow is:
  1. place_futures_order: available_balance -> locked_balance -> used_margin
  2. execute_market_order: fills the order
  3. create_or_update_position: margin stays in used_margin (allocated to position)
*/

-- Fix create_or_update_position to not touch locked_balance
DROP FUNCTION IF EXISTS create_or_update_position(uuid, text, text, numeric, numeric, integer, text, numeric, numeric, numeric);

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
  
  -- Margin is already in used_margin from lock_margin_for_order
  -- It stays there as it's now allocated to the position
  -- No need to move it anywhere
  
  RETURN v_position_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;