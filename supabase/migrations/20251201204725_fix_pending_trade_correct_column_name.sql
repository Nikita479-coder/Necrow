/*
  # Fix Pending Trade Function - Correct Column Name

  ## Overview
  Updates create_pending_copy_trade to use correct column name
  'total_followers_notified' instead of 'total_notified'.

  ## Changes
  - Uses total_followers_notified column
  - Matches actual table schema
  
  ## Security
  - No security changes
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
  -- Check if user is admin (try JWT first, then user_profiles as fallback)
  v_is_admin := COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean,
    false
  );
  
  -- Fallback: check user_profiles table if JWT doesn't have admin flag
  IF NOT v_is_admin THEN
    SELECT is_admin INTO v_is_admin
    FROM user_profiles
    WHERE id = auth.uid();
    
    v_is_admin := COALESCE(v_is_admin, false);
  END IF;

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
      pending_trade_id,
      notification_type,
      notification_status
    ) VALUES (
      v_follower.follower_id,
      v_trade_id,
      'trade_signal',
      'unread'
    );
  END LOOP;

  -- Update the pending trade with follower count
  UPDATE pending_copy_trades
  SET total_followers_notified = v_follower_count
  WHERE id = v_trade_id;

  RETURN v_trade_id;
END;
$$;
