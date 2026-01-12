/*
  # Fix Cross Margin Deadlock Issue

  ## Description
  Removes the trigger that causes deadlocks during position creation.
  The trigger was trying to update all positions after a position insert/update,
  which created a circular dependency.

  ## Solution
  - Remove the automatic trigger
  - Update liquidation prices manually in create_or_update_position function
  - Only update OTHER positions' liquidation prices, not the current one
  - Prevents recursive updates and deadlocks

  ## Changes
  1. Drop the problematic trigger
  2. Modify update_cross_margin_liquidations to exclude current position
  3. Call it explicitly after position creation completes
*/

-- Drop the trigger that causes deadlocks
DROP TRIGGER IF EXISTS on_position_change_update_cross_liquidations ON futures_positions;

-- Update the function to exclude a specific position (the one being created/updated)
CREATE OR REPLACE FUNCTION update_cross_margin_liquidations_except(
  p_user_id uuid,
  p_exclude_position_id uuid DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  v_position record;
  v_new_liq_price numeric;
BEGIN
  -- Update liquidation price for all OTHER open cross margin positions
  FOR v_position IN
    SELECT position_id, side, entry_price, quantity, leverage, pair, mark_price
    FROM futures_positions
    WHERE user_id = p_user_id
      AND status = 'open'
      AND margin_mode = 'cross'
      AND (p_exclude_position_id IS NULL OR position_id != p_exclude_position_id)
  LOOP
    -- Calculate new liquidation price based on current account equity
    v_new_liq_price := calculate_liquidation_price(
      p_user_id,
      v_position.side,
      v_position.entry_price,
      v_position.quantity,
      v_position.mark_price,
      v_position.leverage,
      'cross',
      v_position.pair
    );
    
    -- Update the liquidation price
    UPDATE futures_positions
    SET liquidation_price = v_new_liq_price,
        last_price_update = now()
    WHERE position_id = v_position.position_id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Update create_or_update_position to recalculate other positions AFTER completion
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
  
  -- If cross margin, update OTHER positions' liquidation prices
  -- (account equity changed, so their liquidation prices should update too)
  IF p_margin_mode = 'cross' THEN
    PERFORM update_cross_margin_liquidations_except(p_user_id, v_position_id);
  END IF;
  
  RETURN v_position_id;
END;
$$ LANGUAGE plpgsql;

-- Also update when positions are closed (affects remaining positions)
CREATE OR REPLACE FUNCTION trigger_update_cross_after_close()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update if a cross margin position was closed
  IF OLD.margin_mode = 'cross' AND OLD.status = 'open' AND NEW.status != 'open' THEN
    -- Update all remaining cross margin positions (exclude this one)
    PERFORM update_cross_margin_liquidations_except(OLD.user_id, OLD.position_id);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger only on position close
DROP TRIGGER IF EXISTS on_position_close_update_cross ON futures_positions;
CREATE TRIGGER on_position_close_update_cross
  AFTER UPDATE ON futures_positions
  FOR EACH ROW
  WHEN (OLD.status = 'open' AND NEW.status != 'open')
  EXECUTE FUNCTION trigger_update_cross_after_close();