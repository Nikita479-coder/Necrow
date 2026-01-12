/*
  # Admin Position Edit Functions

  1. Functions
    - `admin_update_position_entry_price` - Update position entry price and recalculate PnL
    - `admin_update_position_pnl` - Set position PnL and calculate required entry price
    - `admin_get_user_live_activity` - Get real-time user activity

  2. Security
    - Only admins can execute these functions
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
  v_new_roe numeric;
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

  -- Calculate new ROE
  v_new_roe := (v_new_pnl / v_position.margin_allocated) * 100;

  -- Update position
  UPDATE futures_positions
  SET
    entry_price = p_new_entry_price,
    unrealized_pnl = v_new_pnl,
    roe = v_new_roe,
    updated_at = now()
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
    'new_pnl', v_new_pnl,
    'new_roe', v_new_roe
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
  v_new_roe numeric;
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

  -- Calculate new ROE
  v_new_roe := (p_target_pnl / v_position.margin_allocated) * 100;

  -- Update position
  UPDATE futures_positions
  SET
    entry_price = v_new_entry_price,
    unrealized_pnl = p_target_pnl,
    roe = v_new_roe,
    updated_at = now()
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
    'new_pnl', p_target_pnl,
    'new_roe', v_new_roe
  );
END;
$$;

-- Function to get user live activity (last 100 activities)
CREATE OR REPLACE FUNCTION admin_get_user_activity(
  p_user_id uuid,
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  activity_type text,
  activity_details jsonb,
  ip_address text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.activity_type,
    a.activity_details,
    a.ip_address,
    a.created_at
  FROM user_activity_log a
  WHERE a.user_id = p_user_id
  ORDER BY a.created_at DESC
  LIMIT p_limit;
END;
$$;