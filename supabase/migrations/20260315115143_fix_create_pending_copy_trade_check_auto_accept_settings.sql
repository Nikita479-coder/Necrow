/*
  # Fix create_pending_copy_trade to also check auto_accept_settings table

  1. Changes
    - Updates `create_pending_copy_trade` function to check `auto_accept_settings` table
      in addition to legacy user_profiles columns
    - Same fix as applied to create_pending_trade_only

  2. Notes
    - Both trade creation functions now consistently check both auto-accept systems
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
  v_auto_accept_result json;
  v_has_auto_accept boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM admin_managed_traders WHERE id = p_trader_id)
     AND NOT EXISTS (SELECT 1 FROM traders WHERE id = p_trader_id)
     AND NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_trader_id) THEN
    RAISE EXCEPTION 'Trader not found: %', p_trader_id;
  END IF;

  v_expires_at := NOW() + INTERVAL '5 minutes';

  INSERT INTO pending_copy_trades (
    trader_id, admin_trader_id, pair, side, entry_price, quantity, leverage,
    margin_used, margin_percentage, notes, trader_balance, status, expires_at
  ) VALUES (
    p_trader_id, NULL, p_pair, p_side, p_entry_price, p_quantity, p_leverage,
    p_margin_used, p_margin_percentage, p_notes, p_trader_balance, 'pending', v_expires_at
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
    WHERE cr.trader_id = p_trader_id
      AND cr.status = 'active'
      AND cr.is_active = true
      AND cr.notification_enabled = true
  LOOP
    INSERT INTO copy_trade_notifications (
      follower_id, pending_trade_id, notification_status, notification_type
    ) VALUES (
      v_follower.follower_id, v_trade_id, 'unread', 'pending_trade'
    ) ON CONFLICT (follower_id, pending_trade_id) DO NOTHING;

    v_follower_count := v_follower_count + 1;

    v_has_auto_accept := false;

    IF v_follower.copy_auto_accept_enabled = true
       AND v_follower.copy_auto_accept_until IS NOT NULL
       AND v_follower.copy_auto_accept_until > NOW() THEN
      v_has_auto_accept := true;
    END IF;

    IF NOT v_has_auto_accept THEN
      SELECT EXISTS (
        SELECT 1 FROM auto_accept_settings
        WHERE follower_id = v_follower.follower_id
          AND trader_id = p_trader_id
          AND is_mock = v_follower.is_mock
          AND expires_at > NOW()
      ) INTO v_has_auto_accept;
    END IF;

    IF v_has_auto_accept THEN
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
