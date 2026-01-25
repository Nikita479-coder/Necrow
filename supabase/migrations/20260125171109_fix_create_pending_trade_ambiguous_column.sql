/*
  # Fix Ambiguous Column Reference in create_pending_trade_only

  ## Summary
  Fixed the "column reference pending_trade_id is ambiguous" error by using
  the explicit constraint name in ON CONFLICT clause.

  ## Changes
  - Changed ON CONFLICT (follower_id, pending_trade_id) to use constraint name
  - Added auto-accept logic for followers with auto-accept enabled
*/

DROP FUNCTION IF EXISTS create_pending_trade_only(uuid, text, text, numeric, numeric, integer, numeric, text, uuid);

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
  v_follower_count integer := 0;
  v_auto_accept_count integer := 0;
  v_trader_balance numeric := 100000;
  v_margin_percentage numeric;
  v_follower RECORD;
  v_auto_accept_result json;
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
    NOW() + INTERVAL '5 minutes',
    0,
    v_trader_trade_id
  ) RETURNING id INTO v_pending_trade_id;

  FOR v_follower IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.allocation_percentage,
      cr.leverage as follower_leverage_multiplier,
      cr.is_mock,
      cr.notification_enabled,
      cr.current_balance,
      up.copy_auto_accept_enabled,
      up.copy_auto_accept_until
    FROM copy_relationships cr
    JOIN user_profiles up ON up.id = cr.follower_id
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
    AND cr.is_active = true
  LOOP
    IF v_follower.notification_enabled THEN
      INSERT INTO copy_trade_notifications (
        follower_id,
        pending_trade_id,
        notification_status,
        notification_type
      ) VALUES (
        v_follower.follower_id,
        v_pending_trade_id,
        'unread',
        'pending_trade'
      ) ON CONFLICT ON CONSTRAINT copy_trade_notifications_follower_id_pending_trade_id_key DO NOTHING;
    END IF;

    v_follower_count := v_follower_count + 1;

    IF v_follower.copy_auto_accept_enabled = true 
       AND v_follower.copy_auto_accept_until IS NOT NULL 
       AND v_follower.copy_auto_accept_until > NOW() THEN
      
      v_auto_accept_result := auto_accept_pending_trade(
        v_pending_trade_id,
        v_follower.follower_id,
        v_follower.relationship_id
      );
      
      IF (v_auto_accept_result->>'success')::boolean = true THEN
        v_auto_accept_count := v_auto_accept_count + 1;
      END IF;
    END IF;
  END LOOP;

  UPDATE pending_copy_trades pct
  SET 
    total_followers_notified = v_follower_count,
    auto_accepted_count = v_auto_accept_count
  WHERE pct.id = v_pending_trade_id;

  RETURN QUERY SELECT v_pending_trade_id, v_trader_trade_id, v_follower_count;
END;
$$;

GRANT EXECUTE ON FUNCTION create_pending_trade_only(uuid, text, text, numeric, numeric, integer, numeric, text, uuid) TO authenticated;
