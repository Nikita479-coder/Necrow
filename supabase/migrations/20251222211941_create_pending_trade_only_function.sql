/*
  # Create Pending Trade Only Function

  1. New Function
    - create_pending_trade_only: Creates a pending trade without immediately executing it
    - Followers will have 10 minutes to accept/decline
    - Only executes trades for followers who accept

  2. Purpose
    - Allow admin to create trade signals that followers can choose to follow
    - Sends Telegram notifications to all followers
    - Waits for acceptance before creating actual positions
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
  v_trader_trade_id uuid;
  v_follower_count integer;
  v_trader_balance numeric := 100000;
  v_margin_percentage numeric;
BEGIN
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can create pending trades';
  END IF;

  v_margin_percentage := (p_margin_used / v_trader_balance) * 100;

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
    NOW() + INTERVAL '10 minutes',
    0,
    v_trader_trade_id
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

  RETURN QUERY SELECT v_pending_trade_id, v_trader_trade_id, v_follower_count;
END;
$$;

GRANT EXECUTE ON FUNCTION create_pending_trade_only(uuid, text, text, numeric, numeric, integer, numeric, text, uuid) TO authenticated;

-- Add trader_trade_id column to pending_copy_trades if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pending_copy_trades' AND column_name = 'trader_trade_id'
  ) THEN
    ALTER TABLE pending_copy_trades ADD COLUMN trader_trade_id uuid REFERENCES trader_trades(id);
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pending_copy_trades' AND column_name = 'margin_percentage'
  ) THEN
    ALTER TABLE pending_copy_trades ADD COLUMN margin_percentage numeric DEFAULT 0;
  END IF;
END $$;
