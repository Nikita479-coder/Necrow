/*
  # Fix respond_to_copy_trade Function

  1. Purpose
    - Drop existing version and create correctly
    - Handle accept/decline for pending trades
    - Only create allocation when user accepts
*/

-- Drop all existing versions
DROP FUNCTION IF EXISTS respond_to_copy_trade(uuid, uuid, text, text, boolean);
DROP FUNCTION IF EXISTS respond_to_copy_trade(uuid, uuid, text, boolean);
DROP FUNCTION IF EXISTS respond_to_pending_trade(uuid, text);

-- Create the function matching frontend calls
CREATE OR REPLACE FUNCTION respond_to_copy_trade(
  p_trade_id uuid,
  p_follower_id uuid,
  p_response text, -- 'accepted' or 'declined'
  p_decline_reason text DEFAULT NULL,
  p_risk_acknowledged boolean DEFAULT true
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending_trade RECORD;
  v_relationship RECORD;
  v_wallet_balance numeric;
  v_allocated_amount numeric;
  v_allocation_id uuid;
  v_wallet_type text;
BEGIN
  -- Verify caller is the follower
  IF auth.uid() != p_follower_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Get pending trade details
  SELECT * INTO v_pending_trade
  FROM pending_copy_trades
  WHERE id = p_trade_id
  AND status = 'pending'
  AND expires_at > NOW();

  IF v_pending_trade IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Trade not found, already responded to, or expired'
    );
  END IF;

  -- Get user's copy relationship with this trader
  SELECT cr.*, 
    CASE WHEN cr.is_mock THEN 'mock' ELSE 'copy' END as wallet_type_name
  INTO v_relationship
  FROM copy_relationships cr
  WHERE cr.trader_id = v_pending_trade.trader_id
  AND cr.follower_id = p_follower_id
  AND cr.status = 'active'
  AND cr.is_active = true;

  IF v_relationship IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'You are not actively copying this trader'
    );
  END IF;

  -- Check if user already has an allocation for this trade
  IF EXISTS (
    SELECT 1 FROM copy_trade_allocations
    WHERE trader_trade_id = v_pending_trade.trader_trade_id
    AND follower_id = p_follower_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'You have already responded to this trade'
    );
  END IF;

  -- Mark notification as read
  UPDATE notifications
  SET read = true
  WHERE user_id = p_follower_id
  AND type = 'pending_copy_trade'
  AND (data->>'pending_trade_id')::uuid = p_trade_id;

  IF p_response = 'declined' THEN
    RETURN json_build_object(
      'success', true,
      'message', 'Trade declined'
    );
  END IF;

  -- ACCEPT flow - create the allocation
  v_wallet_type := v_relationship.wallet_type_name;

  -- Get wallet balance
  SELECT COALESCE(balance, 0) INTO v_wallet_balance
  FROM wallets
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  IF v_wallet_balance IS NULL OR v_wallet_balance <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Insufficient balance in your copy wallet'
    );
  END IF;

  -- Calculate allocation based on user's allocation percentage and the trade's margin percentage
  v_allocated_amount := (v_wallet_balance * v_relationship.allocation_percentage * COALESCE(v_pending_trade.margin_percentage, 10)) / 10000.0;

  -- Minimum allocation check
  IF v_allocated_amount < 1 THEN
    v_allocated_amount := LEAST(v_wallet_balance * 0.1, 10);
  END IF;

  -- Make sure we don't allocate more than available
  IF v_allocated_amount > v_wallet_balance THEN
    v_allocated_amount := v_wallet_balance * 0.95;
  END IF;

  -- Deduct from wallet
  UPDATE wallets
  SET 
    balance = balance - v_allocated_amount,
    updated_at = NOW()
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  -- Create the allocation
  INSERT INTO copy_trade_allocations (
    trader_trade_id,
    follower_id,
    copy_relationship_id,
    allocated_amount,
    follower_leverage,
    entry_price,
    side,
    status,
    source_type
  ) VALUES (
    v_pending_trade.trader_trade_id,
    p_follower_id,
    v_relationship.id,
    v_allocated_amount,
    v_pending_trade.leverage * COALESCE(v_relationship.leverage, 1),
    v_pending_trade.entry_price,
    v_pending_trade.side,
    'open',
    'accepted'
  ) RETURNING id INTO v_allocation_id;

  -- Update relationship stats
  UPDATE copy_relationships
  SET 
    total_trades_copied = COALESCE(total_trades_copied, 0) + 1,
    current_balance = COALESCE(current_balance, 0) + v_allocated_amount
  WHERE id = v_relationship.id;

  -- Create success notification
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_follower_id,
    'copy_trade',
    'Trade Copied Successfully',
    'You have successfully copied a ' || v_pending_trade.pair || ' trade with ' || ROUND(v_allocated_amount, 2)::text || ' USDT',
    false
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Trade accepted successfully',
    'allocation_id', v_allocation_id,
    'allocated_amount', v_allocated_amount
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION respond_to_copy_trade TO authenticated;
