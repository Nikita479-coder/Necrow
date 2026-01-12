/*
  # Allow Admins to Create Pending Trades for Managed Traders

  ## Overview
  Updates `create_pending_copy_trade` to allow admins to create pending trades
  on behalf of managed traders. Regular users can still only create trades as themselves.

  ## Changes
  - Check if user is admin (from JWT metadata)
  - If admin, allow creating trades for any managed trader
  - If not admin, require p_trader_id to match auth.uid()
  - Verify that the trader exists in admin_managed_traders if admin is creating the trade

  ## Security
  - Maintains security for regular users (can only create trades as themselves)
  - Admins can only create trades for traders in admin_managed_traders table
  - Uses JWT metadata to check admin status
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
  p_trader_balance numeric DEFAULT 0
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
  v_expires_at timestamptz;
  v_is_admin boolean;
  v_managed_trader_exists boolean;
BEGIN
  -- Check if user is admin
  v_is_admin := COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean,
    false
  );

  -- If not admin, verify trader is creating trade as themselves
  IF NOT v_is_admin AND p_trader_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only create trades as yourself';
  END IF;

  -- If admin, verify the trader exists in admin_managed_traders
  IF v_is_admin AND p_trader_id != auth.uid() THEN
    SELECT EXISTS(
      SELECT 1 FROM admin_managed_traders WHERE id = p_trader_id
    ) INTO v_managed_trader_exists;

    IF NOT v_managed_trader_exists THEN
      RAISE EXCEPTION 'Trader not found in managed traders';
    END IF;
  END IF;

  -- Validate percentage
  IF p_margin_percentage < 0.01 OR p_margin_percentage > 100 THEN
    RAISE EXCEPTION 'Invalid margin percentage: must be between 0.01 and 100';
  END IF;

  -- Set expiration to 10 minutes from now
  v_expires_at := NOW() + INTERVAL '10 minutes';

  -- Create the pending trade
  INSERT INTO pending_copy_trades (
    trader_id, pair, side, entry_price, quantity, leverage, margin_used,
    margin_percentage, notes, trader_balance, status, expires_at
  ) VALUES (
    p_trader_id, p_pair, p_side, p_entry_price, p_quantity, p_leverage, p_margin_used,
    p_margin_percentage, p_notes, p_trader_balance, 'pending', v_expires_at
  ) RETURNING id INTO v_trade_id;

  -- Create notifications for all active followers
  FOR v_follower IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.allocation_percentage,
      cr.leverage,
      cr.require_approval
    FROM copy_relationships cr
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
    AND cr.require_approval = true
  LOOP
    v_follower_count := v_follower_count + 1;
    
    -- Create notification for follower
    INSERT INTO copy_trade_notifications (
      follower_id,
      trader_id,
      pending_trade_id,
      notification_type,
      title,
      message,
      is_read
    ) VALUES (
      v_follower.follower_id,
      p_trader_id,
      v_trade_id,
      'trade_signal',
      'New Trade Signal',
      format('New %s signal for %s. Review and respond within 10 minutes.', 
        UPPER(p_side), p_pair),
      false
    );
  END LOOP;

  -- Update the pending trade with follower count
  UPDATE pending_copy_trades
  SET total_notified = v_follower_count
  WHERE id = v_trade_id;

  RETURN v_trade_id;
END;
$$;
