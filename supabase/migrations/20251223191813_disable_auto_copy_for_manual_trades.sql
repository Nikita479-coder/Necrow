/*
  # Disable Auto-Copy for Manual Trades

  1. Changes
    - Modify log_trader_position_open to skip auto-copy for manual pending trades
    - Only auto-create allocations if NO pending trade exists
    - Manual trades require explicit user acceptance via respond_to_copy_trade

  2. Purpose
    - Prevent automatic position creation for manual trade signals
    - Users must accept/decline within 5 minutes
    - Auto-copy still works for percentage trades and non-manual trades
*/

-- Update the log_trader_position_open function to check for pending trades
CREATE OR REPLACE FUNCTION log_trader_position_open(
  p_trader_id uuid,
  p_position_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trade_id uuid;
  v_has_pending_trade boolean;
BEGIN
  -- Check if there's an active pending trade for this exact trade
  -- If so, skip auto-allocation (users must accept manually)
  SELECT EXISTS (
    SELECT 1 FROM pending_copy_trades
    WHERE trader_id = p_trader_id
    AND pair = p_pair
    AND side = p_side
    AND entry_price = p_entry_price
    AND leverage = p_leverage
    AND status = 'pending'
    AND expires_at > NOW()
    AND created_at > NOW() - INTERVAL '10 seconds'
  ) INTO v_has_pending_trade;

  -- Insert trader trade record
  INSERT INTO trader_trades (
    trader_id,
    position_id,
    symbol,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    pnl,
    pnl_percent,
    status,
    opened_at
  ) VALUES (
    p_trader_id,
    p_position_id,
    p_pair,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    0,
    0,
    'open',
    NOW()
  ) RETURNING id INTO v_trade_id;

  -- Only create allocations if this is NOT a manual pending trade
  IF NOT v_has_pending_trade THEN
    PERFORM create_follower_allocations(v_trade_id);
  END IF;

  RETURN v_trade_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION log_trader_position_open TO authenticated;
