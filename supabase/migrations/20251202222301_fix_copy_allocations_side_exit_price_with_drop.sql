/*
  # Fix Copy Trade Allocations - Save Side and Exit Price
  
  ## Changes
  1. Drop and recreate execute_accepted_trade to include side when creating allocations
  2. Drop and recreate create_admin_trade to include side
  
  ## Impact
  - Position history will now show long/short
  - Exit prices will be properly saved for PNL calculation
*/

-- Drop and recreate execute_accepted_trade to include side
DROP FUNCTION IF EXISTS execute_accepted_trade(uuid, uuid);

CREATE FUNCTION execute_accepted_trade(
  p_pending_trade_id uuid,
  p_follower_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trade RECORD;
  v_response RECORD;
  v_relationship RECORD;
  v_trader_trade_id uuid;
  v_allocated_amount numeric;
  v_wallet_type text;
BEGIN
  -- Get the pending trade details
  SELECT * INTO v_trade
  FROM pending_copy_trades
  WHERE id = p_pending_trade_id
  AND follower_id = p_follower_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending trade not found';
  END IF;

  -- Get the trade response
  SELECT * INTO v_response
  FROM copy_trade_responses
  WHERE pending_trade_id = p_pending_trade_id
  AND follower_id = p_follower_id
  AND response_status = 'accepted';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No accepted response found';
  END IF;

  -- Get copy relationship
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE trader_id = v_trade.trader_id
  AND follower_id = p_follower_id
  AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active copy relationship not found';
  END IF;

  -- Determine wallet type
  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'copy' END;

  -- Ensure wallet exists
  PERFORM ensure_copy_wallet(p_follower_id, v_wallet_type);

  -- Calculate allocated amount based on percentage
  v_allocated_amount := (v_relationship.allocation_percentage / 100.0) * COALESCE(v_relationship.allocated_amount, 0);

  -- Check if follower has enough balance in copy wallet
  IF NOT EXISTS (
    SELECT 1 FROM wallets
    WHERE user_id = p_follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type
    AND balance >= v_allocated_amount
  ) THEN
    RAISE EXCEPTION 'Insufficient balance in copy wallet';
  END IF;

  -- Deduct from copy wallet
  UPDATE wallets
  SET 
    balance = balance - v_allocated_amount,
    updated_at = NOW()
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  -- Get or create trader_trade_id from the pending trade
  SELECT trader_trade_id INTO v_trader_trade_id
  FROM pending_copy_trades
  WHERE id = p_pending_trade_id;

  -- If no trader_trade exists yet, we need to wait for admin to create it
  IF v_trader_trade_id IS NULL THEN
    RAISE EXCEPTION 'Trader trade not yet created';
  END IF;

  -- Create allocation with side from trader_trades
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
  )
  SELECT
    v_trader_trade_id,
    p_follower_id,
    v_relationship.id,
    v_allocated_amount,
    v_response.follower_leverage,
    v_trade.entry_price,
    tt.side,
    'open',
    'pending_trade'
  FROM trader_trades tt
  WHERE tt.id = v_trader_trade_id;

  -- Mark pending trade as executed
  UPDATE pending_copy_trades
  SET 
    status = 'executed',
    updated_at = NOW()
  WHERE id = p_pending_trade_id;

  -- Mark response as executed
  UPDATE copy_trade_responses
  SET 
    execution_status = 'executed',
    updated_at = NOW()
  WHERE pending_trade_id = p_pending_trade_id
  AND follower_id = p_follower_id;

  -- Create notification for follower
  INSERT INTO notifications (
    user_id,
    notification_type,
    title,
    message,
    is_read
  ) VALUES (
    p_follower_id,
    'copy_trade_executed',
    'Copy Trade Executed',
    'Your copy trade for ' || v_trade.symbol || ' has been executed',
    false
  );
END;
$$;

-- Drop and recreate create_admin_trade to include side in allocation
DROP FUNCTION IF EXISTS create_admin_trade(uuid, text, text, numeric, numeric, integer, numeric, uuid);

CREATE FUNCTION create_admin_trade(
  p_trader_id uuid,
  p_symbol text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_admin_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader_trade_id uuid;
  v_relationship RECORD;
  v_allocated_amount numeric;
  v_wallet_type text;
BEGIN
  -- Verify admin
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can create trades';
  END IF;

  -- Create trader_trade
  INSERT INTO trader_trades (
    trader_id,
    symbol,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    status,
    opened_at,
    created_at
  ) VALUES (
    p_trader_id,
    p_symbol,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    'open',
    NOW(),
    NOW()
  )
  RETURNING id INTO v_trader_trade_id;

  -- Create admin_trader_positions entry for tracking
  INSERT INTO admin_trader_positions (
    trader_id,
    trader_trade_id,
    symbol,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    status,
    opened_at,
    created_at
  ) VALUES (
    p_trader_id,
    v_trader_trade_id,
    p_symbol,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    'open',
    NOW(),
    NOW()
  );

  -- Create allocations for all active copiers
  FOR v_relationship IN
    SELECT *
    FROM copy_relationships
    WHERE trader_id = p_trader_id
    AND status = 'active'
  LOOP
    -- Calculate allocated amount based on percentage
    v_allocated_amount := (v_relationship.allocation_percentage / 100.0) * COALESCE(v_relationship.allocated_amount, 0);
    
    -- Determine wallet type
    v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'copy' END;

    -- Ensure wallet exists
    PERFORM ensure_copy_wallet(v_relationship.follower_id, v_wallet_type);

    -- Skip if insufficient balance
    IF NOT EXISTS (
      SELECT 1 FROM wallets
      WHERE user_id = v_relationship.follower_id
      AND currency = 'USDT'
      AND wallet_type = v_wallet_type
      AND balance >= v_allocated_amount
    ) THEN
      CONTINUE;
    END IF;

    -- Deduct from wallet
    UPDATE wallets
    SET 
      balance = balance - v_allocated_amount,
      updated_at = NOW()
    WHERE user_id = v_relationship.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    -- Create allocation with side
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
      v_trader_trade_id,
      v_relationship.follower_id,
      v_relationship.id,
      v_allocated_amount,
      p_leverage,
      p_entry_price,
      p_side,
      'open',
      'admin_created'
    );
  END LOOP;

  RETURN v_trader_trade_id;
END;
$$;
