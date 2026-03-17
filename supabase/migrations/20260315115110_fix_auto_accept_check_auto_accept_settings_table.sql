/*
  # Fix auto-accept to check auto_accept_settings table

  1. Changes
    - Updates `create_pending_trade_only` function to check the `auto_accept_settings` table
      in addition to the legacy `user_profiles` columns
    - A follower's trade is auto-accepted if EITHER:
      (a) Legacy: user_profiles.copy_auto_accept_enabled = true AND copy_auto_accept_until > NOW()
      (b) New: A matching row exists in auto_accept_settings with expires_at > NOW()

  2. Notes
    - The frontend toggle writes to auto_accept_settings (per-trader, per-mock settings)
    - The old system used global columns on user_profiles
    - This bridges both systems so auto-accept works regardless of which path was used
*/

CREATE OR REPLACE FUNCTION create_pending_trade_only(
  p_admin_id uuid,
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_notes text DEFAULT NULL
)
RETURNS TABLE(pending_trade_id uuid, trader_trade_id uuid, followers_notified integer)
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
  v_has_auto_accept boolean;
BEGIN
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can create pending trades';
  END IF;

  v_margin_percentage := (p_margin_used / v_trader_balance) * 100;

  INSERT INTO trader_trades (
    trader_id, symbol, side, entry_price, quantity, leverage,
    margin_used, pnl, pnl_percent, status, opened_at
  ) VALUES (
    p_trader_id, p_pair, p_side, p_entry_price, p_quantity, p_leverage,
    p_margin_used, 0, 0, 'open', NOW()
  ) RETURNING id INTO v_trader_trade_id;

  INSERT INTO pending_copy_trades (
    trader_id, pair, side, entry_price, quantity, leverage,
    margin_used, notes, trader_balance, margin_percentage,
    status, expires_at, total_followers_notified, trader_trade_id
  ) VALUES (
    p_trader_id, p_pair, p_side, p_entry_price, p_quantity, p_leverage,
    p_margin_used, p_notes, v_trader_balance, v_margin_percentage,
    'pending', NOW() + INTERVAL '5 minutes', 0, v_trader_trade_id
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
        follower_id, pending_trade_id, notification_status, notification_type
      ) VALUES (
        v_follower.follower_id, v_pending_trade_id, 'unread', 'pending_trade'
      ) ON CONFLICT ON CONSTRAINT copy_trade_notifications_follower_id_pending_trade_id_key DO NOTHING;
    END IF;

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
