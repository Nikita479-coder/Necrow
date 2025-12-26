/*
  # Fix Admin Position Edit Functions - Remove ROE

  1. Updates
    - Remove ROE calculations from admin_update_position_entry_price
    - Remove ROE calculations from admin_update_position_pnl
    - Focus on entry price and PnL updates only
*/

-- Function to update position entry price
CREATE OR REPLACE FUNCTION admin_update_position_entry_price(
  p_position_id uuid,
  p_new_entry_price numeric,
  p_admin_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
  v_position record;
  v_current_price numeric;
  v_new_pnl numeric;
BEGIN
  -- Check if user is admin
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = p_admin_user_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can update positions';
  END IF;

  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Position not found';
  END IF;

  -- Use mark price or entry price as current price
  v_current_price := COALESCE(v_position.mark_price, v_position.entry_price);

  -- Calculate new PnL based on new entry price
  IF v_position.side = 'long' THEN
    v_new_pnl := (v_current_price - p_new_entry_price) * v_position.quantity;
  ELSE
    v_new_pnl := (p_new_entry_price - v_current_price) * v_position.quantity;
  END IF;

  -- Update position
  UPDATE futures_positions
  SET
    entry_price = p_new_entry_price,
    unrealized_pnl = v_new_pnl,
    last_price_update = now()
  WHERE position_id = p_position_id;

  -- Log the activity
  PERFORM log_user_activity(
    v_position.user_id,
    'admin_position_edit',
    jsonb_build_object(
      'position_id', p_position_id,
      'admin_user_id', p_admin_user_id,
      'old_entry_price', v_position.entry_price,
      'new_entry_price', p_new_entry_price,
      'old_pnl', v_position.unrealized_pnl,
      'new_pnl', v_new_pnl
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'new_entry_price', p_new_entry_price,
    'new_pnl', v_new_pnl
  );
END;
$$;

-- Function to set PnL and calculate entry price
CREATE OR REPLACE FUNCTION admin_update_position_pnl(
  p_position_id uuid,
  p_target_pnl numeric,
  p_admin_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
  v_position record;
  v_current_price numeric;
  v_new_entry_price numeric;
BEGIN
  -- Check if user is admin
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = p_admin_user_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can update positions';
  END IF;

  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Position not found';
  END IF;

  -- Use mark price or entry price as current price
  v_current_price := COALESCE(v_position.mark_price, v_position.entry_price);

  -- Calculate required entry price to achieve target PnL
  -- For long: PnL = (current_price - entry_price) * quantity
  -- So: entry_price = current_price - (PnL / quantity)
  -- For short: PnL = (entry_price - current_price) * quantity
  -- So: entry_price = current_price + (PnL / quantity)
  
  IF v_position.side = 'long' THEN
    v_new_entry_price := v_current_price - (p_target_pnl / v_position.quantity);
  ELSE
    v_new_entry_price := v_current_price + (p_target_pnl / v_position.quantity);
  END IF;

  -- Update position
  UPDATE futures_positions
  SET
    entry_price = v_new_entry_price,
    unrealized_pnl = p_target_pnl,
    last_price_update = now()
  WHERE position_id = p_position_id;

  -- Log the activity
  PERFORM log_user_activity(
    v_position.user_id,
    'admin_position_edit',
    jsonb_build_object(
      'position_id', p_position_id,
      'admin_user_id', p_admin_user_id,
      'old_entry_price', v_position.entry_price,
      'new_entry_price', v_new_entry_price,
      'old_pnl', v_position.unrealized_pnl,
      'new_pnl', p_target_pnl,
      'edit_type', 'pnl_to_entry'
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'new_entry_price', v_new_entry_price,
    'new_pnl', p_target_pnl
  );
END;
$$;