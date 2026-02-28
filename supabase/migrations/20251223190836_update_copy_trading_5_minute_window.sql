/*
  # Update Copy Trading to 5-Minute Acceptance Window

  1. Changes
    - Update pending trade expiration from 10 to 5 minutes
    - Add better tracking for expired trades
    - Ensure declined/expired trades leave no allocation records

  2. Purpose
    - Give users 5 minutes to accept or decline manual trades
    - Only execute trades for users who explicitly accept
    - Keep percentage-based trades unchanged (instant execution)
*/

-- Update the create_pending_trade_only function to use 5 minutes
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
  v_trader_trade_id uuid;
  v_follower_count integer;
  v_trader_balance numeric := 100000;
  v_margin_percentage numeric;
BEGIN
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can create pending trades';
  END IF;

  -- Calculate margin percentage
  v_margin_percentage := (p_margin_used / v_trader_balance) * 100;

  -- Create the trader's own position first
  INSERT INTO trader_trades (
    trader_id,
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
  ) RETURNING id INTO v_trader_trade_id;

  -- Create pending trade with 5-minute expiration
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
    v_trader_trade_id
  ) RETURNING id INTO v_pending_trade_id;

  -- Count active followers
  SELECT COUNT(*) INTO v_follower_count
  FROM copy_relationships cr
  JOIN user_profiles up ON up.id = cr.follower_id
  WHERE cr.trader_id = p_trader_id
  AND cr.status = 'active'
  AND cr.is_active = true;

  -- Update follower count
  UPDATE pending_copy_trades
  SET total_followers_notified = v_follower_count
  WHERE id = v_pending_trade_id;

  RETURN QUERY SELECT v_pending_trade_id, v_trader_trade_id, v_follower_count;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_pending_trade_only(uuid, text, text, numeric, numeric, integer, numeric, text, uuid) TO authenticated;

-- Create function to auto-expire old pending trades
CREATE OR REPLACE FUNCTION expire_old_pending_trades()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count INTEGER;
BEGIN
  -- Mark expired trades
  UPDATE pending_copy_trades
  SET status = 'expired'
  WHERE status = 'pending'
  AND expires_at < NOW();

  GET DIAGNOSTICS v_expired_count = ROW_COUNT;

  -- Mark associated notifications as expired
  UPDATE copy_trade_notifications
  SET notification_status = 'expired'
  WHERE notification_status = 'unread'
  AND pending_trade_id IN (
    SELECT id FROM pending_copy_trades
    WHERE status = 'expired'
  );

  RETURN v_expired_count;
END;
$$;

GRANT EXECUTE ON FUNCTION expire_old_pending_trades() TO authenticated;

-- Create index for faster expiration queries
CREATE INDEX IF NOT EXISTS idx_pending_trades_expires_status
ON pending_copy_trades(expires_at, status)
WHERE status = 'pending';

-- Add comment explaining the 5-minute window
COMMENT ON TABLE pending_copy_trades IS 'Stores pending manual trades that followers can accept or decline within 5 minutes';
COMMENT ON COLUMN pending_copy_trades.expires_at IS 'Trade expires 5 minutes after creation. Users must respond before this time.';
