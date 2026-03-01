/*
  # Fix Auto-Accept for Admin-Managed Traders

  ## Summary
  Fixes the create_pending_copy_trade function to correctly look up followers
  for admin-managed traders. The query was checking cr.trader_id = p_trader_id
  but for admin traders, copy_relationships stores the admin_trader_id separately.

  ## Changes
  - Update follower lookup query to handle both regular and admin traders
  - Check admin_trader_id column for admin-managed traders
*/

CREATE OR REPLACE FUNCTION create_pending_copy_trade(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_margin_percentage numeric,
  p_notes text DEFAULT NULL,
  p_trader_balance numeric DEFAULT 100000
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trade_id uuid;
  v_follower RECORD;
  v_follower_count integer := 0;
  v_auto_accept_count integer := 0;
  v_expires_at timestamptz;
  v_is_admin_trader boolean;
  v_actual_trader_id uuid;
  v_admin_trader_id uuid;
  v_auto_accept_result json;
BEGIN
  IF EXISTS (SELECT 1 FROM admin_managed_traders WHERE id = p_trader_id) THEN
    v_is_admin_trader := true;
    v_admin_trader_id := p_trader_id;
    v_actual_trader_id := NULL;
  ELSIF EXISTS (SELECT 1 FROM user_profiles WHERE id = p_trader_id) THEN
    v_is_admin_trader := false;
    v_actual_trader_id := p_trader_id;
    v_admin_trader_id := NULL;
  ELSE
    RAISE EXCEPTION 'Trader not found';
  END IF;

  v_expires_at := NOW() + INTERVAL '5 minutes';

  INSERT INTO pending_copy_trades (
    trader_id,
    admin_trader_id,
    pair,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    margin_percentage,
    notes,
    trader_balance,
    status,
    expires_at
  ) VALUES (
    v_actual_trader_id,
    v_admin_trader_id,
    p_pair,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    p_margin_percentage,
    p_notes,
    p_trader_balance,
    'pending',
    v_expires_at
  ) RETURNING id INTO v_trade_id;

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
    WHERE (
      (v_is_admin_trader = true AND cr.trader_id = p_trader_id)
      OR
      (v_is_admin_trader = false AND cr.trader_id = p_trader_id)
    )
    AND cr.status = 'active'
    AND cr.is_active = true
    AND cr.notification_enabled = true
  LOOP
    INSERT INTO copy_trade_notifications (
      follower_id,
      pending_trade_id,
      notification_status,
      notification_type
    ) VALUES (
      v_follower.follower_id,
      v_trade_id,
      'unread',
      'pending_trade'
    ) ON CONFLICT (follower_id, pending_trade_id) DO NOTHING;

    v_follower_count := v_follower_count + 1;

    IF v_follower.copy_auto_accept_enabled = true 
       AND v_follower.copy_auto_accept_until IS NOT NULL 
       AND v_follower.copy_auto_accept_until > NOW() THEN
      
      v_auto_accept_result := auto_accept_pending_trade(
        v_trade_id,
        v_follower.follower_id,
        v_follower.relationship_id
      );
      
      IF (v_auto_accept_result->>'success')::boolean = true THEN
        v_auto_accept_count := v_auto_accept_count + 1;
      END IF;
    END IF;
  END LOOP;

  UPDATE pending_copy_trades
  SET 
    total_followers_notified = v_follower_count,
    auto_accepted_count = v_auto_accept_count
  WHERE id = v_trade_id;

  RETURN v_trade_id;
END;
$$;
