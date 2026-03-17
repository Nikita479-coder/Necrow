/*
  # Fix Flip Trader Trade Side Function - Use Correct Log Table

  1. Changes
    - Update admin_action_logs to admin_activity_logs (correct table name)
    - Add proper column names for the logging table

  2. Purpose
    - Fix the "relation admin_action_logs does not exist" error
*/

CREATE OR REPLACE FUNCTION flip_trader_trade_side(
  p_trade_id uuid,
  p_admin_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trade RECORD;
  v_new_side text;
  v_allocations_updated integer := 0;
BEGIN
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Unauthorized - Admin access required'
    );
  END IF;

  SELECT * INTO v_trade
  FROM trader_trades
  WHERE id = p_trade_id
  AND status = 'open';

  IF v_trade IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Trade not found or not open'
    );
  END IF;

  IF v_trade.side = 'long' THEN
    v_new_side := 'short';
  ELSE
    v_new_side := 'long';
  END IF;

  UPDATE trader_trades
  SET 
    side = v_new_side,
    updated_at = NOW()
  WHERE id = p_trade_id;

  UPDATE copy_trade_allocations
  SET 
    side = v_new_side,
    updated_at = NOW()
  WHERE trader_trade_id = p_trade_id
  AND status = 'open';

  GET DIAGNOSTICS v_allocations_updated = ROW_COUNT;

  INSERT INTO admin_activity_logs (
    admin_id,
    action_type,
    action_description,
    metadata
  ) VALUES (
    p_admin_id,
    'flip_trade_side',
    format('Flipped trade %s from %s to %s', p_trade_id, v_trade.side, v_new_side),
    jsonb_build_object(
      'trade_id', p_trade_id,
      'symbol', v_trade.symbol,
      'old_side', v_trade.side,
      'new_side', v_new_side,
      'allocations_updated', v_allocations_updated
    )
  );

  RETURN json_build_object(
    'success', true,
    'message', format('Position flipped from %s to %s', v_trade.side, v_new_side),
    'old_side', v_trade.side,
    'new_side', v_new_side,
    'allocations_updated', v_allocations_updated
  );
END;
$$;
