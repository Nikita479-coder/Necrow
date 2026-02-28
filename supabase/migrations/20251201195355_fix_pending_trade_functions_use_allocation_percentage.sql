/*
  # Fix Pending Trade Functions to Use allocation_percentage

  ## Overview
  Updates functions to use `allocation_percentage` instead of the renamed `copy_amount` column.

  ## Changes
  1. `create_pending_copy_trade` - Use `allocation_percentage` in SELECT
  2. `respond_to_copy_trade` - Use `allocation_percentage` for calculations

  ## Notes
  The `copy_amount` column was renamed to `allocation_percentage` in an earlier migration
  but these functions were still referencing the old column name.
*/

-- Drop and recreate create_pending_copy_trade with correct column name
DROP FUNCTION IF EXISTS create_pending_copy_trade(uuid, text, text, numeric, numeric, integer, numeric, numeric, text, numeric);

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
BEGIN
  -- Verify trader
  IF p_trader_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only create trades as yourself';
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
      cr.leverage as follower_leverage_multiplier,
      cr.is_mock,
      cr.notification_enabled,
      cr.require_approval
    FROM copy_relationships cr
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
    AND cr.is_active = true
    AND cr.require_approval = true
    AND cr.notification_enabled = true
  LOOP
    -- Create notification for this follower
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
  END LOOP;

  -- Update the trade with follower count
  UPDATE pending_copy_trades
  SET total_followers_notified = v_follower_count
  WHERE id = v_trade_id;

  RETURN v_trade_id;
END;
$$;

-- Drop and recreate respond_to_copy_trade with correct column name
DROP FUNCTION IF EXISTS respond_to_copy_trade(uuid, uuid, text, text, boolean);

CREATE OR REPLACE FUNCTION respond_to_copy_trade(
  p_trade_id uuid,
  p_follower_id uuid,
  p_response text,
  p_decline_reason text DEFAULT NULL,
  p_risk_acknowledged boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_response_id uuid;
  v_trade RECORD;
  v_relationship RECORD;
  v_allocated_amount numeric;
  v_wallet_type text;
  v_current_balance numeric;
BEGIN
  -- Verify user
  IF p_follower_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only respond as yourself';
  END IF;

  -- Validate response type
  IF p_response NOT IN ('accepted', 'declined') THEN
    RAISE EXCEPTION 'Invalid response type';
  END IF;

  -- Get trade details
  SELECT * INTO v_trade
  FROM pending_copy_trades
  WHERE id = p_trade_id;

  IF v_trade IS NULL THEN
    RAISE EXCEPTION 'Trade not found';
  END IF;

  -- Check if trade is still pending
  IF v_trade.status != 'pending' THEN
    RAISE EXCEPTION 'Trade is no longer pending';
  END IF;

  -- Check if trade has expired
  IF v_trade.expires_at < NOW() THEN
    RAISE EXCEPTION 'Trade has expired';
  END IF;

  -- Get relationship details
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE follower_id = p_follower_id
  AND trader_id = v_trade.trader_id
  AND status = 'active'
  AND is_active = true;

  IF v_relationship IS NULL THEN
    RAISE EXCEPTION 'No active copy relationship found';
  END IF;

  -- Check if already responded
  IF EXISTS (
    SELECT 1 FROM copy_trade_responses
    WHERE pending_trade_id = p_trade_id
    AND follower_id = p_follower_id
  ) THEN
    RAISE EXCEPTION 'Already responded to this trade';
  END IF;

  -- If accepting, validate risk acknowledgment
  IF p_response = 'accepted' AND NOT p_risk_acknowledged THEN
    RAISE EXCEPTION 'Must acknowledge risk to accept trade';
  END IF;

  -- Determine wallet type
  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'spot' END;

  -- Get follower's current balance
  SELECT balance INTO v_current_balance
  FROM wallets
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  IF v_current_balance IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;

  -- Calculate allocated amount based on PERCENTAGE of follower's balance
  -- Base allocation: follower_balance × trade_percentage
  v_allocated_amount := (v_current_balance * v_trade.margin_percentage) / 100.0;

  -- Apply relationship multiplier if configured
  -- Example: If follower set to copy at 50%, they use 50% of the calculated amount
  IF v_relationship.allocation_percentage IS NOT NULL AND v_relationship.allocation_percentage > 0 THEN
    v_allocated_amount := v_allocated_amount * (v_relationship.allocation_percentage / 100.0);
  END IF;

  -- Validate sufficient balance if accepting
  IF p_response = 'accepted' THEN
    IF v_current_balance < v_allocated_amount THEN
      RAISE EXCEPTION 'Insufficient balance: need % but have %', v_allocated_amount, v_current_balance;
    END IF;

    -- Ensure minimum allocation
    IF v_allocated_amount < 1 THEN
      RAISE EXCEPTION 'Calculated allocation too small: minimum $1 required';
    END IF;
  END IF;

  -- Create response record
  INSERT INTO copy_trade_responses (
    pending_trade_id,
    follower_id,
    copy_relationship_id,
    response,
    decline_reason,
    risk_acknowledged,
    allocated_amount,
    follower_leverage,
    responded_at
  ) VALUES (
    p_trade_id,
    p_follower_id,
    v_relationship.id,
    p_response,
    p_decline_reason,
    p_risk_acknowledged,
    v_allocated_amount,
    v_trade.leverage * v_relationship.leverage,
    NOW()
  ) RETURNING id INTO v_response_id;

  -- Update notification status
  UPDATE copy_trade_notifications
  SET 
    notification_status = 'responded',
    responded_at = NOW()
  WHERE follower_id = p_follower_id
  AND pending_trade_id = p_trade_id;

  -- Update trade stats
  IF p_response = 'accepted' THEN
    UPDATE pending_copy_trades
    SET total_accepted = total_accepted + 1
    WHERE id = p_trade_id;

    -- Execute the trade immediately for this follower
    PERFORM execute_accepted_trade(p_trade_id, p_follower_id);
  ELSE
    UPDATE pending_copy_trades
    SET total_declined = total_declined + 1
    WHERE id = p_trade_id;
  END IF;

  RETURN v_response_id;
END;
$$;
