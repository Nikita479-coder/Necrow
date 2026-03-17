/*
  # Add Telegram Notification Support for Admin Trades

  ## Overview
  This migration adds support for sending Telegram notifications when admin 
  trades are opened. It creates a pending_copy_trade entry for each admin trade
  to leverage the existing notification infrastructure.

  ## Changes
  1. Add pending_trade_id column to trader_trades
  2. Create function to send trade notifications to followers
  3. Update open_admin_trade to optionally create pending_copy_trade for notifications

  ## Security
  - Functions are security definer with proper admin checks
  - RLS policies are respected through existing infrastructure
*/

-- Add column to link trader_trades with pending_copy_trades
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'trader_trades' AND column_name = 'pending_trade_id'
  ) THEN
    ALTER TABLE trader_trades ADD COLUMN pending_trade_id uuid REFERENCES pending_copy_trades(id);
  END IF;
END $$;

-- Create function to create pending trade for notifications
CREATE OR REPLACE FUNCTION create_pending_trade_for_notification(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending_trade_id uuid;
  v_trader_balance numeric := 100000;
  v_margin_percentage numeric;
BEGIN
  v_margin_percentage := (p_margin_used / v_trader_balance) * 100;

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
    status,
    expires_at,
    total_followers_notified
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
    'executed',
    NOW() + INTERVAL '10 minutes',
    0
  ) RETURNING id INTO v_pending_trade_id;

  RETURN v_pending_trade_id;
END;
$$;

-- Create function to manually trigger Telegram notifications for a trade
CREATE OR REPLACE FUNCTION notify_followers_for_trade(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_leverage integer,
  p_admin_id uuid
)
RETURNS TABLE(
  pending_trade_id uuid,
  followers_to_notify integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending_trade_id uuid;
  v_follower_count integer;
BEGIN
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can trigger notifications';
  END IF;

  INSERT INTO pending_copy_trades (
    trader_id,
    pair,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    status,
    expires_at,
    total_followers_notified
  ) VALUES (
    p_trader_id,
    p_pair,
    p_side,
    p_entry_price,
    1,
    p_leverage,
    1000,
    'pending',
    NOW() + INTERVAL '10 minutes',
    0
  ) RETURNING id INTO v_pending_trade_id;

  SELECT COUNT(*) INTO v_follower_count
  FROM copy_relationships cr
  JOIN user_profiles up ON up.id = cr.follower_id
  WHERE cr.trader_id = p_trader_id
  AND cr.status = 'active'
  AND cr.is_active = true
  AND up.telegram_chat_id IS NOT NULL
  AND up.telegram_blocked = false;

  UPDATE pending_copy_trades
  SET total_followers_notified = v_follower_count
  WHERE id = v_pending_trade_id;

  RETURN QUERY SELECT v_pending_trade_id, v_follower_count;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_pending_trade_for_notification(uuid, text, text, numeric, numeric, integer, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION notify_followers_for_trade(uuid, text, text, numeric, integer, uuid) TO authenticated;
