/*
  # Fix Admin Position Edit Functions - Correct Column Names

  1. Updates
    - Fix `admin_update_position_entry_price` to use `last_price` instead of `price`
    - Fix `admin_update_position_pnl` to use `last_price` instead of `price`
    - Remove references to non-existent `roe` and `margin_used` columns
    - Use correct column names from futures_positions table
*/

-- Fix admin_update_position_entry_price function
CREATE OR REPLACE FUNCTION admin_update_position_entry_price(
  p_position_id uuid,
  p_new_entry_price numeric,
  p_admin_user_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_new_pnl numeric;
  v_current_price numeric;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found');
  END IF;

  -- Get current price (use last_price, not price)
  SELECT last_price INTO v_current_price
  FROM market_prices
  WHERE pair = v_position.pair
  ORDER BY last_updated DESC
  LIMIT 1;

  -- Use mark_price from position as fallback
  IF v_current_price IS NULL THEN
    v_current_price := COALESCE(v_position.mark_price, v_position.entry_price);
  END IF;

  -- Calculate new PnL
  IF v_position.side = 'long' THEN
    v_new_pnl := (v_current_price - p_new_entry_price) * v_position.quantity;
  ELSE
    v_new_pnl := (p_new_entry_price - v_current_price) * v_position.quantity;
  END IF;

  -- Update position (remove roe column reference)
  UPDATE futures_positions
  SET 
    entry_price = p_new_entry_price,
    unrealized_pnl = v_new_pnl,
    last_price_update = now()
  WHERE position_id = p_position_id;

  -- LOG ADMIN ACTION
  PERFORM log_admin_action(
    p_admin_user_id,
    'position_entry_price_edit',
    format('Updated entry price for %s position on %s', v_position.side, v_position.pair),
    v_position.user_id,
    jsonb_build_object(
      'position_id', p_position_id,
      'pair', v_position.pair,
      'side', v_position.side,
      'old_entry_price', v_position.entry_price,
      'new_entry_price', p_new_entry_price,
      'old_pnl', v_position.unrealized_pnl,
      'new_pnl', v_new_pnl,
      'current_price', v_current_price
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'new_pnl', v_new_pnl,
    'old_entry_price', v_position.entry_price,
    'new_entry_price', p_new_entry_price
  );
END;
$$;

-- Fix admin_update_position_pnl function
CREATE OR REPLACE FUNCTION admin_update_position_pnl(
  p_position_id uuid,
  p_target_pnl numeric,
  p_admin_user_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_new_entry_price numeric;
  v_current_price numeric;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found');
  END IF;

  -- Get current price (use last_price, not price)
  SELECT last_price INTO v_current_price
  FROM market_prices
  WHERE pair = v_position.pair
  ORDER BY last_updated DESC
  LIMIT 1;

  -- Use mark_price from position as fallback
  IF v_current_price IS NULL THEN
    v_current_price := COALESCE(v_position.mark_price, v_position.entry_price);
  END IF;

  -- Calculate new entry price to achieve target PnL
  IF v_position.side = 'long' THEN
    v_new_entry_price := v_current_price - (p_target_pnl / v_position.quantity);
  ELSE
    v_new_entry_price := v_current_price + (p_target_pnl / v_position.quantity);
  END IF;

  -- Update position (remove roe column reference)
  UPDATE futures_positions
  SET 
    entry_price = v_new_entry_price,
    unrealized_pnl = p_target_pnl,
    last_price_update = now()
  WHERE position_id = p_position_id;

  -- LOG ADMIN ACTION
  PERFORM log_admin_action(
    p_admin_user_id,
    'position_pnl_edit',
    format('Updated PnL for %s position on %s', v_position.side, v_position.pair),
    v_position.user_id,
    jsonb_build_object(
      'position_id', p_position_id,
      'pair', v_position.pair,
      'side', v_position.side,
      'old_entry_price', v_position.entry_price,
      'new_entry_price', v_new_entry_price,
      'old_pnl', v_position.unrealized_pnl,
      'new_pnl', p_target_pnl,
      'current_price', v_current_price
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'new_entry_price', v_new_entry_price,
    'old_pnl', v_position.unrealized_pnl,
    'new_pnl', p_target_pnl
  );
END;
$$;