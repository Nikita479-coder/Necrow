/*
  # Fix Copy Trading - Pending Only, No Auto Copy

  1. Changes
    - Modify open_admin_trade to NOT auto-create copy allocations
    - Instead, only create the trader trade and pending_copy_trades record
    - Users must explicitly accept trades before they are copied
    - Fix margin_percentage constraint to allow flexible values

  2. Flow
    - Admin opens trade -> Creates trader_trade + pending_copy_trades
    - Trigger sends notifications to followers
    - User clicks Accept -> Creates their copy_trade_allocation
    - User clicks Decline or timeout -> Trade is not copied for them
*/

-- First, drop all versions of open_admin_trade
DROP FUNCTION IF EXISTS open_admin_trade(uuid, text, text, numeric, numeric, integer, boolean);
DROP FUNCTION IF EXISTS open_admin_trade(uuid, text, text, numeric, numeric, integer, numeric, text, uuid);

-- Fix margin_percentage constraint to be more flexible
ALTER TABLE pending_copy_trades DROP CONSTRAINT IF EXISTS pending_copy_trades_margin_percentage_check;
ALTER TABLE pending_copy_trades ADD CONSTRAINT pending_copy_trades_margin_percentage_check 
  CHECK (margin_percentage >= 0 AND margin_percentage <= 100);

-- Also fix margin_used constraint to allow 0
ALTER TABLE pending_copy_trades DROP CONSTRAINT IF EXISTS pending_copy_trades_margin_used_check;

-- Create new open_admin_trade that ONLY creates pending trades
CREATE OR REPLACE FUNCTION open_admin_trade(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_notes text DEFAULT NULL,
  p_admin_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position_id uuid;
  v_trader_trade_id uuid;
  v_margin_percentage numeric;
  v_pending_trade_id uuid;
  v_has_active_followers boolean;
BEGIN
  -- Check if user is admin
  IF NOT COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false) THEN
    RAISE EXCEPTION 'Only admins can create trades';
  END IF;

  -- Calculate margin percentage (assuming 100k base for display)
  v_margin_percentage := LEAST(GREATEST((p_margin_used / 1000.0), 0.1), 100);

  -- Create the trader trade record
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

  -- Create admin position record
  INSERT INTO admin_trader_positions (
    trader_id,
    pair,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    status,
    notes,
    created_by,
    opened_at,
    trader_trade_id
  ) VALUES (
    p_trader_id,
    p_pair,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    'open',
    p_notes,
    COALESCE(p_admin_id, auth.uid()),
    NOW(),
    v_trader_trade_id
  ) RETURNING id INTO v_position_id;

  -- Check if there are active followers
  SELECT EXISTS(
    SELECT 1 FROM copy_relationships cr
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
    AND cr.is_active = true
  ) INTO v_has_active_followers;

  -- Create pending copy trade for followers to accept/decline
  -- This will trigger notifications via the trigger we created
  IF v_has_active_followers THEN
    INSERT INTO pending_copy_trades (
      trader_id,
      trader_trade_id,
      pair,
      side,
      entry_price,
      leverage,
      margin_used,
      margin_percentage,
      status,
      expires_at
    ) VALUES (
      p_trader_id,
      v_trader_trade_id,
      p_pair,
      p_side,
      p_entry_price,
      p_leverage,
      p_margin_used,
      v_margin_percentage,
      'pending',
      NOW() + INTERVAL '10 minutes'
    ) RETURNING id INTO v_pending_trade_id;
  END IF;

  -- DO NOT create copy_trade_allocations here
  -- Users must explicitly accept the trade first

  RETURN v_position_id;
END;
$$;

-- Update respond_to_pending_trade to properly create allocation when accepted
CREATE OR REPLACE FUNCTION respond_to_pending_trade(
  p_pending_trade_id uuid,
  p_response text -- 'accept' or 'decline'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending_trade RECORD;
  v_user_id uuid;
  v_relationship RECORD;
  v_wallet_balance numeric;
  v_allocated_amount numeric;
  v_allocation_id uuid;
  v_wallet_type text;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get pending trade details
  SELECT * INTO v_pending_trade
  FROM pending_copy_trades
  WHERE id = p_pending_trade_id
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
    CASE WHEN cr.is_mock THEN 'mock' ELSE 'copy' END as wallet_type
  INTO v_relationship
  FROM copy_relationships cr
  WHERE cr.trader_id = v_pending_trade.trader_id
  AND cr.follower_id = v_user_id
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
    AND follower_id = v_user_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'You have already responded to this trade'
    );
  END IF;

  IF p_response = 'decline' THEN
    -- Just record the decline, no allocation created
    RETURN json_build_object(
      'success', true,
      'message', 'Trade declined'
    );
  END IF;

  -- ACCEPT flow - create the allocation
  v_wallet_type := v_relationship.wallet_type;

  -- Get wallet balance
  SELECT COALESCE(balance, 0) INTO v_wallet_balance
  FROM wallets
  WHERE user_id = v_user_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  IF v_wallet_balance IS NULL OR v_wallet_balance <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Insufficient balance in your copy wallet'
    );
  END IF;

  -- Calculate allocation based on user's allocation percentage and the trade's margin percentage
  v_allocated_amount := (v_wallet_balance * v_relationship.allocation_percentage * v_pending_trade.margin_percentage) / 10000.0;

  -- Minimum allocation check
  IF v_allocated_amount < 1 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Calculated allocation too small. Need more balance.'
    );
  END IF;

  -- Make sure we don't allocate more than available
  IF v_allocated_amount > v_wallet_balance THEN
    v_allocated_amount := v_wallet_balance * 0.95; -- Use 95% max
  END IF;

  -- Deduct from wallet
  UPDATE wallets
  SET 
    balance = balance - v_allocated_amount,
    updated_at = NOW()
  WHERE user_id = v_user_id
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
    v_user_id,
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

  RETURN json_build_object(
    'success', true,
    'message', 'Trade accepted successfully',
    'allocation_id', v_allocation_id,
    'allocated_amount', v_allocated_amount
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION open_admin_trade TO authenticated;
GRANT EXECUTE ON FUNCTION respond_to_pending_trade TO authenticated;
