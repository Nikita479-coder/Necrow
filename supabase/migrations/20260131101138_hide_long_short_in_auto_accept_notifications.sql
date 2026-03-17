/*
  # Hide Long/Short in Auto-Accept Notifications

  ## Summary
  Updates the auto-accept notification message to exclude position direction (long/short)
  to protect trader strategy while maintaining transparency about trade execution.

  ## Changes
  - Removes `side` from auto-accept notification message
  - Adds entry price for context instead
  - Message format: "Auto-accepted BTC/USDT trade with 100.00 USDT at $45,230.50"

  ## Security
  - Prevents followers from knowing trader's position direction
  - Maintains user transparency about trade execution
  - Consistent with Telegram notifications which already hide side
*/

-- Update auto_accept function to hide long/short in notification
CREATE OR REPLACE FUNCTION auto_accept_pending_trade(
  p_trade_id uuid,
  p_follower_id uuid,
  p_relationship_id uuid
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
  v_trader_trade_id uuid;
  v_effective_percentage numeric;
BEGIN
  -- Check if already responded
  IF EXISTS (
    SELECT 1 FROM pending_trade_responses ptr
    WHERE ptr.pending_trade_id = p_trade_id
    AND ptr.follower_id = p_follower_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Already responded to this trade'
    );
  END IF;

  -- Get pending trade
  SELECT * INTO v_pending_trade
  FROM pending_copy_trades pct
  WHERE pct.id = p_trade_id
  AND pct.status = 'pending'
  AND pct.expires_at > NOW();

  IF v_pending_trade IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Trade expired or not found'
    );
  END IF;

  -- Get relationship
  SELECT cr.*,
    CASE WHEN cr.is_mock THEN 'mock' ELSE 'copy' END as wallet_type_name
  INTO v_relationship
  FROM copy_relationships cr
  WHERE cr.id = p_relationship_id
  AND cr.follower_id = p_follower_id
  AND cr.status = 'active'
  AND cr.is_active = true;

  IF v_relationship IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Relationship not active'
    );
  END IF;

  -- Record response as auto-accepted
  INSERT INTO pending_trade_responses (
    pending_trade_id,
    follower_id,
    response,
    decline_reason,
    auto_accepted
  ) VALUES (
    p_trade_id,
    p_follower_id,
    'accepted',
    'auto-accepted',
    true
  );

  -- Create trader trade if needed
  IF v_pending_trade.trader_trade_id IS NULL THEN
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
      COALESCE(v_pending_trade.admin_trader_id, v_pending_trade.trader_id),
      v_pending_trade.pair,
      v_pending_trade.side,
      v_pending_trade.entry_price,
      v_pending_trade.quantity,
      v_pending_trade.leverage,
      v_pending_trade.margin_used,
      0,
      0,
      'open',
      NOW()
    ) RETURNING id INTO v_trader_trade_id;

    UPDATE pending_copy_trades pct
    SET trader_trade_id = v_trader_trade_id
    WHERE pct.id = p_trade_id;
  ELSE
    v_trader_trade_id := v_pending_trade.trader_trade_id;
  END IF;

  v_wallet_type := v_relationship.wallet_type_name;

  -- Get wallet balance
  SELECT COALESCE(w.balance, 0) INTO v_wallet_balance
  FROM wallets w
  WHERE w.user_id = p_follower_id
  AND w.currency = 'USDT'
  AND w.wallet_type = v_wallet_type;

  IF v_wallet_balance IS NULL OR v_wallet_balance <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Insufficient balance'
    );
  END IF;

  -- Calculate allocated amount
  v_effective_percentage := LEAST(
    v_relationship.allocation_percentage,
    COALESCE(v_pending_trade.margin_percentage, v_relationship.allocation_percentage)
  );

  v_allocated_amount := v_wallet_balance * v_effective_percentage / 100.0;

  IF v_allocated_amount < 1 THEN
    v_allocated_amount := LEAST(v_wallet_balance * 0.1, 10);
  END IF;

  IF v_allocated_amount > v_wallet_balance THEN
    v_allocated_amount := v_wallet_balance * 0.95;
  END IF;

  -- Deduct from wallet
  UPDATE wallets w
  SET
    balance = w.balance - v_allocated_amount,
    updated_at = NOW()
  WHERE w.user_id = p_follower_id
  AND w.currency = 'USDT'
  AND w.wallet_type = v_wallet_type;

  -- Create allocation
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
    p_follower_id,
    v_relationship.id,
    v_allocated_amount,
    v_pending_trade.leverage * COALESCE(v_relationship.leverage, 1),
    v_pending_trade.entry_price,
    v_pending_trade.side,
    'open',
    'auto_accepted'
  ) RETURNING id INTO v_allocation_id;

  -- Update relationship stats
  UPDATE copy_relationships cr
  SET
    total_trades_copied = COALESCE(cr.total_trades_copied, 0) + 1,
    updated_at = NOW()
  WHERE cr.id = v_relationship.id;

  -- Update pending trade stats
  UPDATE pending_copy_trades pct
  SET total_accepted = pct.total_accepted + 1
  WHERE pct.id = p_trade_id;

  -- Mark existing notification as read
  UPDATE notifications n
  SET read = true
  WHERE n.user_id = p_follower_id
  AND n.type = 'pending_copy_trade'
  AND (n.data->>'pending_trade_id')::uuid = p_trade_id;

  -- Create notification WITHOUT revealing long/short direction
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_follower_id,
    'copy_trade',
    'Trade Auto-Accepted',
    'Auto-accepted ' || v_pending_trade.pair || ' trade with ' || ROUND(v_allocated_amount, 2)::text || ' USDT at $' || ROUND(v_pending_trade.entry_price, 2)::text,
    false
  );

  RETURN json_build_object(
    'success', true,
    'allocation_id', v_allocation_id,
    'allocated_amount', v_allocated_amount
  );
END;
$$;