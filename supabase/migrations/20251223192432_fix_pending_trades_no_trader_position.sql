/*
  # Fix Pending Trades - Don't Create Trader Position Upfront

  1. Changes
    - Modify create_pending_trade_only to NOT create trader_trades record
    - Only create pending_copy_trades record
    - trader_trades will be created later when first follower accepts

  2. Purpose
    - Prevent "phantom" positions showing in Live Positions
    - Trader position should only exist when actual followers are copying it
    - Keep pending trades truly pending until accepted
*/

CREATE OR REPLACE FUNCTION create_pending_trade_only(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_notes text,
  p_admin_id uuid
)
RETURNS TABLE(
  pending_trade_id uuid,
  trader_trade_id uuid,
  follower_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending_trade_id uuid;
  v_follower_count integer;
  v_trader_balance numeric := 100000;
  v_margin_percentage numeric;
BEGIN
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can create pending trades';
  END IF;

  v_margin_percentage := (p_margin_used / v_trader_balance) * 100;

  -- Create ONLY the pending trade, NOT the trader_trades record
  INSERT INTO pending_copy_trades (
    trader_id,
    pair,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    notes,
    trader_balance,
    margin_percentage,
    status,
    expires_at,
    total_followers_notified,
    trader_trade_id
  ) VALUES (
    p_trader_id,
    p_pair,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    p_notes,
    v_trader_balance,
    v_margin_percentage,
    'pending',
    NOW() + INTERVAL '5 minutes',
    0,
    NULL  -- No trader_trade_id yet
  ) RETURNING id INTO v_pending_trade_id;

  SELECT COUNT(*) INTO v_follower_count
  FROM copy_relationships cr
  JOIN user_profiles up ON up.id = cr.follower_id
  WHERE cr.trader_id = p_trader_id
  AND cr.status = 'active'
  AND cr.is_active = true;

  UPDATE pending_copy_trades
  SET total_followers_notified = v_follower_count
  WHERE id = v_pending_trade_id;

  -- Return with NULL trader_trade_id since we didn't create one
  RETURN QUERY SELECT v_pending_trade_id, NULL::uuid, v_follower_count;
END;
$$;

GRANT EXECUTE ON FUNCTION create_pending_trade_only(uuid, text, text, numeric, numeric, integer, numeric, text, uuid) TO authenticated;
