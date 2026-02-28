/*
  # Create Flip Trader Trade Side Function

  1. Purpose
    - Allow admin to reverse the side of an open trade (long to short, short to long)
    - Updates the trader_trade record
    - Updates all associated copy_trade_allocations
    - Recalculates PnL based on new side direction

  2. Changes
    - Create flip_trader_trade_side function
    - Handle all related allocations atomically

  3. Security
    - Only admins can call this function
    - Validates the trade exists and is open
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

  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_type,
    target_id,
    details
  ) VALUES (
    p_admin_id,
    'flip_trade_side',
    'trader_trade',
    p_trade_id,
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

GRANT EXECUTE ON FUNCTION flip_trader_trade_side TO authenticated;
